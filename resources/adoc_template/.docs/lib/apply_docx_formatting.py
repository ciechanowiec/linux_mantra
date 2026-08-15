#!/usr/bin/env python3
"""Apply post-conversion formatting fixes to a Pandoc-generated DOCX.

A DOCX is a zip archive of XML parts. This script unpacks the archive,
runs a pipeline of small string-level transforms against the parts that
need fixing (numbering.xml, styles.xml, document.xml), and repacks.

To add a new fix: write a function `(xml: str) -> str` near the other
transforms for its target part, then append it to the matching list in
`TRANSFORMS`. See each transform's banner for the WHY behind it.

Usage: python3 apply_docx_formatting.py <path-to-docx>
"""
import os
import re
import shutil
import sys
import tempfile
import zipfile
from typing import Callable, Dict, List

XmlTransform = Callable[[str], str]


# ============================================================================
# numbering.xml -- heading multilevel numbering
# ============================================================================
#
# Pandoc rebuilds word/numbering.xml from scratch when converting, so the
# multilevel list definitions cannot live solely in the reference DOCX. The
# reference DOCX binds Heading1-6 styles to numId=9001; this transform adds
# the matching multilevel abstractNum so Word renders 1, 1.1, 1.1.1, ... and
# renumbers when sections are added or removed.

HEADING_ABSTRACT_NUM_ID = "9991"
HEADING_NUM_ID = "9001"
HEADING_NSID = "170cd2df"  # distinctive marker for idempotency check

_heading_levels = []
for i in range(9):
    pstyle = f'<w:pStyle w:val="Heading{i+1}" />' if i < 6 else ''
    lvl_text = '.'.join(f'%{j+1}' for j in range(i + 1)) + '.'
    # Every section identifier starts at the body-text margin, whatever the
    # section's depth, and the title hangs: wrapped title lines start at the
    # same column as the title text after the number. The hang widens per
    # level and is sized for the widest realistic number -- two digits per
    # component, "10.11." -- because a number wider than the hang makes the
    # tab overshoot to the next default stop and break the alignment.
    hang = 720 + 360 * i
    _heading_levels.append(
        f'<w:lvl w:ilvl="{i}">'
        f'<w:start w:val="1" />'
        f'<w:numFmt w:val="decimal" />'
        f'{pstyle}'
        f'<w:suff w:val="tab" />'
        f'<w:lvlText w:val="{lvl_text}" />'
        f'<w:lvlJc w:val="left" />'
        f'<w:pPr><w:ind w:left="{hang}" w:hanging="{hang}" /></w:pPr>'
        f'</w:lvl>'
    )

HEADING_ABSTRACT_NUM = (
    f'<w:abstractNum w:abstractNumId="{HEADING_ABSTRACT_NUM_ID}">'
    f'<w:nsid w:val="{HEADING_NSID}" />'
    f'<w:multiLevelType w:val="multilevel" />'
    f'<w:tmpl w:val="00000001" />'
    + ''.join(_heading_levels) +
    f'</w:abstractNum>'
)
HEADING_NUM = (
    f'<w:num w:numId="{HEADING_NUM_ID}">'
    f'<w:abstractNumId w:val="{HEADING_ABSTRACT_NUM_ID}" />'
    f'</w:num>'
)


def _inject_heading_numbering(numbering_xml: str) -> str:
    if f'<w:nsid w:val="{HEADING_NSID}" />' in numbering_xml:
        return numbering_xml
    insertion_point = numbering_xml.find('<w:abstractNum ')
    if insertion_point == -1:
        open_tag_end = numbering_xml.find('>', numbering_xml.find('<w:numbering')) + 1
        return (
            numbering_xml[:open_tag_end]
            + HEADING_ABSTRACT_NUM + HEADING_NUM
            + numbering_xml[open_tag_end:]
        )
    patched = (
        numbering_xml[:insertion_point]
        + HEADING_ABSTRACT_NUM
        + numbering_xml[insertion_point:]
    )
    return patched.replace('</w:numbering>', HEADING_NUM + '</w:numbering>')


# ============================================================================
# numbering.xml -- ordered-list multilevel numbering
# ============================================================================
#
# Pandoc emits each nesting level of an ordered list as a separate
# single-format abstract (one for decimal, one for lowerLetter, etc.), so
# Word treats them as disconnected lists. When the author edits a list
# manually, Word picks its own scheme for the new level. This transform
# defines one 9-level multilevel ordered-list abstract matching the
# HTML/PDF exports (upperalpha, upperroman, lowergreek, lowerroman, then
# lowerroman repeated -- see adoc-css-style.css and common-style.rb) and
# remaps every ordered-list <w:num> to point at it. Each <w:num> keeps its
# own startOverride entries, so independent lists still restart at
# A / I / α / i.
#
# ST_NumberFormat has no Greek value, so the lowergreek level rides the
# w14 `custom` format inside an mc:AlternateContent, the same markup Word
# itself writes for non-enum formats. Word 2010+ and LibreOffice take the
# w14 branch; anything older takes the lowerLetter fallback. The mc/w14
# namespaces this needs are declared by _declare_compat_namespaces below.

ORDERED_ABSTRACT_NUM_ID = "9992"
ORDERED_NSID = "170cd2e0"  # distinctive marker for idempotency check

LOWER_GREEK_NUMFMT = (
    '<mc:AlternateContent>'
    '<mc:Choice Requires="w14">'
    '<w:numFmt w:val="custom" w:format="α, β, γ, ..." />'
    '</mc:Choice>'
    '<mc:Fallback><w:numFmt w:val="lowerLetter" /></mc:Fallback>'
    '</mc:AlternateContent>'
)

ORDERED_NUMFMT_TAGS = [
    '<w:numFmt w:val="upperLetter" />',
    '<w:numFmt w:val="upperRoman" />',
    LOWER_GREEK_NUMFMT,
] + ['<w:numFmt w:val="lowerRoman" />'] * 6

# Upper-letter lists need room for Word's post-Z labels (AA., BB., ...).
# Roman levels use a five-eighths-inch gutter so labels through XVIII., XIX.,
# and comparable lower-Roman values retain space before their text tab.
ORDERED_GUTTER_DXA = [540, 900, 360] + [900] * 6
ORDERED_TEXT_LEFT_DXA = []
_ordered_levels = []
ordered_marker_left = 0
for i, numfmt_tag in enumerate(ORDERED_NUMFMT_TAGS):
    # Every marker begins at the text column of its parent level. Roman
    # numerals need a wider gutter than letters or Greek labels; otherwise
    # VII. and VIII. cross the text tab and Word advances only those items
    # to the next default stop. A variable gutter preserves both invariants:
    # hierarchical marker starts and one text column within each level.
    gutter = ORDERED_GUTTER_DXA[i]
    ind_left = ordered_marker_left + gutter
    ORDERED_TEXT_LEFT_DXA.append(ind_left)
    _ordered_levels.append(
        f'<w:lvl w:ilvl="{i}">'
        f'<w:start w:val="1" />'
        f'{numfmt_tag}'
        f'<w:suff w:val="tab" />'
        f'<w:lvlText w:val="%{i+1}." />'
        f'<w:lvlJc w:val="left" />'
        f'<w:pPr><w:tabs><w:tab w:val="num" w:pos="{ind_left}" />'
        f'</w:tabs><w:ind w:left="{ind_left}" w:hanging="{gutter}" />'
        f'</w:pPr>'
        f'</w:lvl>'
    )
    ordered_marker_left = ind_left

ORDERED_ABSTRACT_NUM = (
    f'<w:abstractNum w:abstractNumId="{ORDERED_ABSTRACT_NUM_ID}">'
    f'<w:nsid w:val="{ORDERED_NSID}" />'
    f'<w:multiLevelType w:val="multilevel" />'
    f'<w:tmpl w:val="00000002" />'
    + ''.join(_ordered_levels) +
    f'</w:abstractNum>'
)

ORDERED_FMT_RE = re.compile(
    r'<w:numFmt w:val="(decimal|decimalZero|lowerLetter|lowerRoman'
    r'|upperLetter|upperRoman)"'
)

# Pandoc's numbering.xml declares only the main wordprocessingml namespace,
# but the lowergreek level above needs mc:AlternateContent and a
# Requires="w14" reference. Declare both namespaces on the root element and
# list w14 as mc:Ignorable so a consumer without the extension skips it
# cleanly instead of rejecting the part.

NUMBERING_ROOT_RE = re.compile(r'<w:numbering\b[^>]*>')
MC_IGNORABLE_RE = re.compile(r'mc:Ignorable="([^"]*)"')
MC_XMLNS = 'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"'
W14_XMLNS = 'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"'


def _declare_compat_namespaces(numbering_xml: str) -> str:
    root_match = NUMBERING_ROOT_RE.search(numbering_xml)
    if not root_match:
        return numbering_xml
    tag = new_tag = root_match.group(0)
    if 'xmlns:mc=' not in new_tag:
        new_tag = new_tag[:-1] + f' {MC_XMLNS}>'
    if 'xmlns:w14=' not in new_tag:
        new_tag = new_tag[:-1] + f' {W14_XMLNS}>'
    ignorable = MC_IGNORABLE_RE.search(new_tag)
    if not ignorable:
        new_tag = new_tag[:-1] + ' mc:Ignorable="w14">'
    elif 'w14' not in ignorable.group(1).split():
        new_tag = new_tag.replace(
            ignorable.group(0), f'mc:Ignorable="{ignorable.group(1)} w14"', 1,
        )
    return numbering_xml.replace(tag, new_tag, 1)


def _unify_ordered_lists(numbering_xml: str) -> str:
    if f'<w:nsid w:val="{ORDERED_NSID}" />' in numbering_xml:
        # Replace the generated abstract instead of returning unchanged, so
        # running a newer post-processor over an older converted DOCX also
        # picks up numbering-layout fixes.
        abstract_start = numbering_xml.find(
            f'<w:abstractNum w:abstractNumId="{ORDERED_ABSTRACT_NUM_ID}">'
        )
        abstract_end = numbering_xml.find('</w:abstractNum>', abstract_start)
        if abstract_start != -1 and abstract_end != -1:
            abstract_end += len('</w:abstractNum>')
            return (
                numbering_xml[:abstract_start]
                + ORDERED_ABSTRACT_NUM
                + numbering_xml[abstract_end:]
            )
        return numbering_xml

    ordered_abstract_ids = set()
    for am in re.finditer(
        r'<w:abstractNum w:abstractNumId="(\d+)">(.*?)</w:abstractNum>',
        numbering_xml,
        re.DOTALL,
    ):
        aid, body = am.group(1), am.group(2)
        first_lvl = re.search(r'<w:lvl w:ilvl="0">(.*?)</w:lvl>', body, re.DOTALL)
        if not first_lvl or not ORDERED_FMT_RE.search(first_lvl.group(1)):
            continue
        if re.search(r'<w:pStyle w:val="Heading\d+"', body):
            continue
        ordered_abstract_ids.add(aid)

    insertion_point = numbering_xml.find('<w:abstractNum ')
    if insertion_point == -1:
        open_tag_end = numbering_xml.find('>', numbering_xml.find('<w:numbering')) + 1
        numbering_xml = (
            numbering_xml[:open_tag_end]
            + ORDERED_ABSTRACT_NUM
            + numbering_xml[open_tag_end:]
        )
    else:
        numbering_xml = (
            numbering_xml[:insertion_point]
            + ORDERED_ABSTRACT_NUM
            + numbering_xml[insertion_point:]
        )

    def remap(match: 're.Match[str]') -> str:
        body = match.group(0)
        am = re.search(r'<w:abstractNumId w:val="(\d+)" />', body)
        if am and am.group(1) in ordered_abstract_ids:
            body = re.sub(
                r'<w:abstractNumId w:val="\d+" />',
                f'<w:abstractNumId w:val="{ORDERED_ABSTRACT_NUM_ID}" />',
                body,
                count=1,
            )
        return body

    return re.sub(
        r'<w:num w:numId="\d+">.*?</w:num>',
        remap,
        numbering_xml,
        flags=re.DOTALL,
    )


# ============================================================================
# numbering.xml -- bullet lists on the same margin ladder
# ============================================================================
#
# Ordered lists hang each level's identifier at the text column of the
# level above (see `_ordered_levels` above), but bullet lists keep Pandoc's
# stock ladder of (level+1)*720. A bullet nested under ordered items would
# then sit off the ladder. The writing guideline uses ordered levels 0-3
# and bullet levels 4-5. Put the first bullet marker at ordered level 3's
# text column, then continue with a 360-twip bullet gutter.

BULLET_ABSTRACT_RE = re.compile(
    r'<w:abstractNum\b[^>]*>.*?</w:abstractNum>', re.DOTALL)
BULLET_LVL_RE = re.compile(r'<w:lvl w:ilvl="(\d)"[^>]*>.*?</w:lvl>',
                           re.DOTALL)
BULLET_IND_RE = re.compile(r'<w:ind w:left="\d+" w:hanging="360" />')


def _align_bullet_lists(numbering_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        seg = match.group(0)
        first = re.search(r'<w:lvl w:ilvl="0">.*?</w:lvl>', seg, re.DOTALL)
        if not first or '<w:numFmt w:val="bullet" />' not in first.group(0):
            return seg

        def reladder(lvl: 're.Match[str]') -> str:
            level = int(lvl.group(1))
            if level == 0:
                marker_left = 0
            elif level <= 4:
                marker_left = ORDERED_TEXT_LEFT_DXA[level - 1]
            else:
                marker_left = ORDERED_TEXT_LEFT_DXA[3] + (level - 4) * 360
            left = marker_left + 360
            return BULLET_IND_RE.sub(
                f'<w:ind w:left="{left}" w:hanging="360" />', lvl.group(0))

        return BULLET_LVL_RE.sub(reladder, seg)

    return BULLET_ABSTRACT_RE.sub(fix, numbering_xml)


# ============================================================================
# styles.xml -- symmetric heading spacing
# ============================================================================
#
# The reference styles give headings a large space before and a small space
# after (e.g. Heading2: 160/80), while body paragraphs contribute the same
# 180 above and below. The gap over a heading therefore beats the gap under
# it. Copying `before` into `after` makes both sums equal, so a heading
# floats evenly between its neighbors.

HEADING_STYLE_RE = re.compile(
    r'<w:style\b[^>]*w:styleId="Heading\d"[^>]*>.*?</w:style>', re.DOTALL)


def _symmetric_heading_spacing(styles_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        seg = match.group(0)
        spacing = re.search(r'<w:spacing\b[^/]*/>', seg)
        if not spacing:
            return seg
        before = re.search(r'w:before="(\d+)"', spacing.group(0))
        if not before:
            return seg
        tag = spacing.group(0)
        if 'w:after="' in tag:
            new_tag = re.sub(r'w:after="\d+"',
                             f'w:after="{before.group(1)}"', tag)
        else:
            new_tag = tag[:-2] + f'w:after="{before.group(1)}" />'
        return seg.replace(tag, new_tag, 1)

    return HEADING_STYLE_RE.sub(fix, styles_xml)


# ============================================================================
# styles.xml -- SourceCode justification
# ============================================================================
#
# Normal is justified (w:jc=both), and Pandoc's SourceCode paragraph style is
# basedOn Normal without overriding jc, so code blocks inherit justification
# and Word spreads tokens to fill the line. Force SourceCode to left-align.

SOURCECODE_STYLE_RE = re.compile(
    r'(<w:style\b[^>]*w:styleId="SourceCode"[^>]*>)(.*?)(</w:style>)',
    re.DOTALL,
)
SOURCECODE_PPR_RE = re.compile(r'<w:pPr\b[^>]*>(.*?)</w:pPr>', re.DOTALL)


def _left_align_source_code(styles_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        open_tag, body, close_tag = match.group(1), match.group(2), match.group(3)
        if '<w:jc ' in body:
            return match.group(0)
        ppr_match = SOURCECODE_PPR_RE.search(body)
        if ppr_match:
            new_ppr = (
                ppr_match.group(0).rsplit('</w:pPr>', 1)[0]
                + '<w:jc w:val="left" /></w:pPr>'
            )
            body = body[:ppr_match.start()] + new_ppr + body[ppr_match.end():]
        else:
            body = '<w:pPr><w:jc w:val="left" /></w:pPr>' + body
        return open_tag + body + close_tag
    return SOURCECODE_STYLE_RE.sub(fix, styles_xml, count=1)


# ============================================================================
# styles.xml -- footnote size and paragraph spacing
# ============================================================================
#
# FootnoteText in the reference DOCX carries no overrides, so footnotes
# inherit the document defaults: 12 pt runs and 200 twips of space after
# every paragraph (each footnote is one FootnoteText paragraph, so that
# space shows up between footnotes). Pin the style to 10 pt with zero
# before/after spacing so the distance between footnote paragraphs equals
# the distance between lines, and give it a hanging indent so the footnote
# number dangles left of the vertical line that all text lines share.
#
# The hanging amount is deliberately the natural width of "superscript
# digit + one word space" so that the layout needs NO tab character: a
# footnote that simply reads "number, space, text" self-aligns, including
# footnotes inserted later in a word processor with no post-processing
# (Word/LibreOffice add the number automatically; the author types the
# space as part of normal writing). A style cannot inject content, so any
# design needing a tab would silently break hand-added footnotes; w:fitText
# and style-bound list numbering were tried as automatic alternatives and
# LibreOffice ignores both inside the footnote area. The value below was
# measured from LibreOffice's rendering of the reference theme font at
# 10 pt (digit 65 + space 51 twips); remeasure if the document font or the
# footnote font size changes. Known sub-millimetre drift: 2-digit numbers
# (one extra digit width) and fully-justified first lines (the separator
# space stretches with justification).
#
# FootnoteBlockText (block content inside a footnote) starts with no
# number, so it gets a plain left indent on the same vertical line instead
# of a hanging one, and its own 100-twip margins are zeroed too.

FOOTNOTE_HANGING_DXA = 116  # superscript digit (65) + word space (51) at 10 pt

FOOTNOTE_PPR_BY_STYLE = {
    'FootnoteText': (
        '<w:spacing w:before="0" w:after="0" />'
        f'<w:ind w:left="{FOOTNOTE_HANGING_DXA}" '
        f'w:hanging="{FOOTNOTE_HANGING_DXA}" />'
    ),
    'FootnoteBlockText': (
        '<w:spacing w:before="0" w:after="0" />'
        f'<w:ind w:left="{FOOTNOTE_HANGING_DXA}" w:firstLine="0" />'
    ),
}
FOOTNOTE_STYLE_RE = re.compile(
    r'(<w:style\b[^>]*w:styleId="(FootnoteText|FootnoteBlockText)"[^>]*>)'
    r'(.*?)(</w:style>)',
    re.DOTALL,
)
FOOTNOTE_RPR_TAG = '<w:rPr><w:sz w:val="20" /><w:szCs w:val="20" /></w:rPr>'
STYLE_SPACING_RE = re.compile(r'<w:spacing\b[^/]*/>')
STYLE_IND_RE = re.compile(r'<w:ind\b[^/]*/>')


def _compact_footnotes(styles_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        open_tag, style_id = match.group(1), match.group(2)
        body, close_tag = match.group(3), match.group(4)
        ppr_tags = FOOTNOTE_PPR_BY_STYLE[style_id]
        ppr_match = SOURCECODE_PPR_RE.search(body)
        if ppr_match:
            ppr = ppr_match.group(0)
            ppr = STYLE_SPACING_RE.sub('', ppr)
            ppr = STYLE_IND_RE.sub('', ppr)
            ppr = ppr.rsplit('</w:pPr>', 1)[0] + ppr_tags + '</w:pPr>'
            body = body[:ppr_match.start()] + ppr + body[ppr_match.end():]
        else:
            body = body + '<w:pPr>' + ppr_tags + '</w:pPr>'
        if '<w:sz ' not in body:
            body = body + FOOTNOTE_RPR_TAG
        return open_tag + body + close_tag
    return FOOTNOTE_STYLE_RE.sub(fix, styles_xml)


# ============================================================================
# footnotes.xml -- exactly one space after the footnote number
# ============================================================================
#
# The hanging indent of FootnoteText equals the natural width of
# "superscript number + one word space" (see the styles transform above),
# so the generated footnotes must read exactly "number, space, text" to
# sit on the vertical line -- same as a footnote typed by hand later.
# Pandoc already separates the number from the text with a space run;
# normalize the other shapes to it (a legacy tab run from earlier versions
# of this script is dropped, a leading space inside the first text run is
# folded into the separator run). Continuation paragraphs of a
# multi-paragraph footnote carry no number; cancel their inherited hanging
# indent so their first line sits on the same vertical line as everything
# else.

_RPR = r'(?:<w:rPr>(?:(?!</w:rPr>).)*?</w:rPr>)?'
FOOTNOTE_SEPARATOR_RUN = '<w:r><w:t xml:space="preserve"> </w:t></w:r>'
FOOTNOTE_NUMBER_RE = re.compile(
    # the run holding the footnote number
    r'(<w:r\b[^>]*>(?:(?!</w:r>).)*?<w:footnoteRef\s*/>\s*</w:r>)'
    # an existing separator space run (re-emitted in canonical form)
    rf'(?:<w:r\b[^>]*>{_RPR}<w:t(?: [^>]*)?> </w:t></w:r>)?'
    # a legacy tab run (dropped)
    rf'(?:<w:r\b[^>]*>{_RPR}\s*<w:tab\s*/>\s*</w:r>)?'
    # the opening of the following text run, incl. a leading space (Word)
    rf'((?:<w:r\b[^>]*>{_RPR}<w:t(?: [^>]*)?> ?)?)',
    re.DOTALL,
)
FOOTNOTE_PSTYLE_RE = re.compile(r'<w:pStyle w:val="FootnoteText"\s*/?>')


def _space_after_footnote_number(footnotes_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        text_open = match.group(2)
        if text_open.endswith(' '):
            text_open = text_open[:-1]
        return match.group(1) + FOOTNOTE_SEPARATOR_RUN + text_open
    return FOOTNOTE_NUMBER_RE.sub(fix, footnotes_xml)


def _align_footnote_continuations(footnotes_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        para = match.group(0)
        if '<w:footnoteRef' in para or '<w:ind ' in para:
            return para
        if not FOOTNOTE_PSTYLE_RE.search(para):
            return para
        return FOOTNOTE_PSTYLE_RE.sub(
            '<w:pStyle w:val="FootnoteText" />'
            f'<w:ind w:left="{FOOTNOTE_HANGING_DXA}" w:hanging="0" />',
            para,
            count=1,
        )
    return PARAGRAPH_RE.sub(fix, footnotes_xml)


# ============================================================================
# document.xml -- author/email separator
# ============================================================================
#
# Pandoc joins the AsciiDoc :author: and :email: with a single space, so the
# byline renders as "Firstname Lastname email@host". Insert " | " before the
# email so the byline reads "Firstname Lastname | email@host".

AUTHOR_PARA_RE = re.compile(
    r'<w:p>\s*<w:pPr>\s*<w:pStyle w:val="Author"\s*/>\s*</w:pPr>.*?</w:p>',
    re.DOTALL,
)
EMAIL_SEP_RE = re.compile(r' ([\w.+\-]+@[\w.\-]+)')


def _separate_author_email(document_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        para = match.group(0)
        if ' | ' in para:
            return para
        return EMAIL_SEP_RE.sub(r' | \1', para, count=1)
    return AUTHOR_PARA_RE.sub(fix, document_xml)


# ============================================================================
# document.xml -- empty heading paragraphs
# ============================================================================
#
# With :doctype: book, Asciidoctor wraps any content between the document
# title and the first chapter in a DocBook <preface> with an empty <title/>.
# Pandoc renders that as an empty Heading1 paragraph, which the multilevel
# numbering above then decorates with a stray "1." and bumps every
# subsequent chapter number by one. Drop Heading1-6 paragraphs whose text
# runs are empty.

PARAGRAPH_RE = re.compile(r'<w:p\b[^>]*>.*?</w:p>', re.DOTALL)
HEADING_PSTYLE_RE = re.compile(r'<w:pStyle w:val="Heading[1-6]"')
TEXT_RUN_RE = re.compile(r'<w:t[^>]*>([^<]*)</w:t>')


def _strip_empty_headings(document_xml: str) -> str:
    def keep_or_drop(match: 're.Match[str]') -> str:
        body = match.group(0)
        if not HEADING_PSTYLE_RE.search(body):
            return body
        if any(t.strip() for t in TEXT_RUN_RE.findall(body)):
            return body
        return ''
    return PARAGRAPH_RE.sub(keep_or_drop, document_xml)


# ============================================================================
# document.xml -- paragraph headers stay with their continuation
# ============================================================================
#
# A numbered paragraph header is a bold-only list item followed by its body as
# continuation content. Pandoc emits the two parts as adjacent paragraphs.
# Without keepNext, Word can leave the header at the foot of one page and move
# its body to the next. Mark every bold-only numbered paragraph keep-with-next,
# which preserves the source's header-and-body unit without affecting ordinary
# bold text or numbered paragraphs that contain prose.

RUN_RE = re.compile(r'<w:r\b[^>]*>.*?</w:r>', re.DOTALL)
NUMPR_RE = re.compile(r'<w:numPr>')


# ============================================================================
# document.xml / footnotes.xml -- highlighted placeholders
# ============================================================================
#
# Asciidoctor converts `#[placeholder]#` to DocBook
# `<emphasis role="marked">`, but Pandoc's DocBook reader discards the
# `marked` role and keeps only an emphasis node. The DOCX therefore receives
# italic text without the yellow highlight. Highlighted fill-in fields in this
# project have one unambiguous visible form: an italic run whose complete text
# is enclosed in square brackets. Give those runs Word's native yellow
# highlight and remove one italic layer -- the layer Pandoc created from the
# mark. If the source deliberately nests the mark inside italics, Pandoc emits
# two italic properties and one remains after this transform.

PLACEHOLDER_TEXT_RE = re.compile(r'^\[[^\[\]\r\n]+\]$')
ITALIC_PROP_RE = re.compile(r'<w:i(?:\s[^>]*)?\s*/>')
ITALIC_CS_PROP_RE = re.compile(r'<w:iCs(?:\s[^>]*)?\s*/>')
YELLOW_HIGHLIGHT = '<w:highlight w:val="yellow" />'


def _highlight_placeholders(part_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        run = match.group(0)
        text = ''.join(TEXT_RUN_RE.findall(run))
        if not PLACEHOLDER_TEXT_RE.fullmatch(text) or '<w:i' not in run:
            return run
        if YELLOW_HIGHLIGHT in run:
            return run

        run = ITALIC_PROP_RE.sub('', run, count=1)
        run = ITALIC_CS_PROP_RE.sub('', run, count=1)
        rpr_end = run.find('</w:rPr>')
        if rpr_end != -1:
            return run[:rpr_end] + YELLOW_HIGHLIGHT + run[rpr_end:]

        run_open_end = run.find('>') + 1
        return (run[:run_open_end] + '<w:rPr>' + YELLOW_HIGHLIGHT
                + '</w:rPr>' + run[run_open_end:])

    return RUN_RE.sub(fix, part_xml)


def _keep_paragraph_headers_with_body(document_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        para = match.group(0)
        ppr_match = PARA_PPR_RE.search(para)
        if not ppr_match or not NUMPR_RE.search(ppr_match.group(0)):
            return para
        text_runs = [
            run.group(0)
            for run in RUN_RE.finditer(para)
            if any(text.strip() for text in TEXT_RUN_RE.findall(run.group(0)))
        ]
        if not text_runs or any('<w:b' not in run for run in text_runs):
            return para
        ppr = ppr_match.group(0)
        if '<w:keepNext' in ppr:
            return para
        insert_at = ppr.find('>') + 1
        style = re.search(r'<w:pStyle\b[^/]*/>', ppr)
        if style:
            insert_at = style.end()
        patched_ppr = ppr[:insert_at] + '<w:keepNext />' + ppr[insert_at:]
        return para.replace(ppr, patched_ppr, 1)

    return PARAGRAPH_RE.sub(fix, document_xml)


# ============================================================================
# document.xml -- section-title bookmarks
# ============================================================================
#
# Asciidoctor assigns every section an anchor id and Pandoc materializes
# each one as a bookmark around the heading, which Word and LibreOffice
# then display as bookmark markers next to the section titles and as
# X<sha1> entries in the bookmarks list. Drop every bookmark that nothing
# references; bookmarks targeted by an internal hyperlink or a REF-style
# field (AsciiDoc cross-references) are kept so those links keep working.

BOOKMARK_START_RE = re.compile(r'<w:bookmarkStart w:id="(\d+)" w:name="([^"]*)"\s*/>\s*')
BOOKMARK_END_RE = re.compile(r'<w:bookmarkEnd w:id="(\d+)"\s*/>\s*')
ANCHOR_REF_RE = re.compile(r'w:anchor="([^"]+)"')
INSTR_TEXT_RE = re.compile(r'<w:instrText[^>]*>([^<]*)</w:instrText>')
FIELD_REF_RE = re.compile(r'(?:PAGEREF|REF|HYPERLINK\s+\\l)\s+"?([^"\s\\]+)')


def _collect_referenced_anchors(part_xmls: List[str]) -> set:
    referenced = set()
    for xml in part_xmls:
        referenced.update(ANCHOR_REF_RE.findall(xml))
        for instr in INSTR_TEXT_RE.findall(xml):
            referenced.update(FIELD_REF_RE.findall(instr))
    return referenced


def _make_strip_bookmarks(referenced: set) -> XmlTransform:
    def _strip_bookmarks(document_xml: str) -> str:
        dropped_ids = set()

        def drop_start(match: 're.Match[str]') -> str:
            if match.group(2) in referenced:
                return match.group(0)
            dropped_ids.add(match.group(1))
            return ''

        document_xml = BOOKMARK_START_RE.sub(drop_start, document_xml)
        if dropped_ids:
            document_xml = BOOKMARK_END_RE.sub(
                lambda m: '' if m.group(1) in dropped_ids else m.group(0),
                document_xml,
            )
        return document_xml
    return _strip_bookmarks


# ============================================================================
# document.xml -- A4 page size and margins
# ============================================================================
#
# Pandoc's reference.docx doesn't carry an explicit page size, so Word falls
# back to its locale default (Letter on US installs, A4 on EU). Pin the body
# section to A4 with 1" margins so the rendered DOCX is consistent everywhere.

PG_WIDTH_A4_DXA = 11906   # 210mm at 1440 dxa/inch
PG_HEIGHT_A4_DXA = 16838  # 297mm
PG_MARGIN_DXA = 1440      # 1 inch margins
USABLE_TEXT_WIDTH_DXA = PG_WIDTH_A4_DXA - 2 * PG_MARGIN_DXA  # = 9026
EMU_PER_DXA = 914400 // 1440  # = 635, EMUs per twip

PG_SZ_TAG = f'<w:pgSz w:w="{PG_WIDTH_A4_DXA}" w:h="{PG_HEIGHT_A4_DXA}" />'
PG_MAR_TAG = (
    f'<w:pgMar w:top="{PG_MARGIN_DXA}" w:right="{PG_MARGIN_DXA}" '
    f'w:bottom="{PG_MARGIN_DXA}" w:left="{PG_MARGIN_DXA}" '
    f'w:header="720" w:footer="720" w:gutter="0" />'
)

SECT_PR_RE = re.compile(r'(<w:sectPr\b[^>]*>)(.*?)(</w:sectPr>)', re.DOTALL)
PG_SZ_EXISTING_RE = re.compile(r'<w:pgSz\b[^/]*/?>')
PG_MAR_EXISTING_RE = re.compile(r'<w:pgMar\b[^/]*/?>')


def _force_a4_section(document_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        open_tag, body, close_tag = match.group(1), match.group(2), match.group(3)
        if PG_SZ_EXISTING_RE.search(body):
            body = PG_SZ_EXISTING_RE.sub(PG_SZ_TAG, body, count=1)
        else:
            body = body + PG_SZ_TAG
        if PG_MAR_EXISTING_RE.search(body):
            body = PG_MAR_EXISTING_RE.sub(PG_MAR_TAG, body, count=1)
        else:
            body = body + PG_MAR_TAG
        return open_tag + body + close_tag
    return SECT_PR_RE.sub(fix, document_xml)


# ============================================================================
# document.xml -- table widths
# ============================================================================
#
# Pandoc emits each table with <w:tblW w:type="pct" w:w="5000" /> (= 100% of
# the parent width) plus <w:tblLayout w:type="fixed"/> and absolute gridCol
# widths. When a table is nested inside a list, Pandoc also adds an absolute
# <w:tblInd w:w="1440"/>; Word then renders the table at "100% of text area"
# AND offsets it by the indent, so the right edge spills past the margin.
# Rewrite each table to size = usable_text_width - tblInd so the right edge
# lines up with the body-text right margin while the indent is preserved on
# the left. Column proportions are kept by scaling gridCol values to that
# new total.
#
# Word additionally starts a table's grid at tblInd minus the leading cell
# margin, so a table without tblInd juts its left border one cell margin
# past the text edge and stops one short on the right. Writing tblInd =
# intended_indent + cell_margin puts both borders exactly on the paragraph
# verticals. Source-fields tables are borderless and skip the nudge.

TABLE_RE = re.compile(r'<w:tbl>.*?</w:tbl>', re.DOTALL)
TBL_IND_RE = re.compile(r'<w:tblInd w:w="(\d+)" w:type="dxa"\s*/>')
TBL_CELL_SIDE_MARGIN = 108  # the Table style's left/right tblCellMar
TBL_W_RE = re.compile(r'<w:tblW [^/]*/>')
TBL_GRID_RE = re.compile(r'<w:tblGrid>(.*?)</w:tblGrid>', re.DOTALL)
GRID_COL_RE = re.compile(r'<w:gridCol w:w="(\d+)"\s*/>')
TC_W_RE = re.compile(r'<w:tcW w:w="(\d+)" w:type="dxa"\s*/>')


def _fit_table_widths(document_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        body = match.group(0)
        ind_match = TBL_IND_RE.search(body)
        indent = int(ind_match.group(1)) if ind_match else 0
        grid_match = TBL_GRID_RE.search(body)
        if not grid_match:
            return body
        cols = [int(w) for w in GRID_COL_RE.findall(grid_match.group(1))]
        if not cols:
            return body
        total = sum(cols)
        budget = USABLE_TEXT_WIDTH_DXA - indent
        if budget <= 0 or total <= 0:
            return body
        new_cols = [max(1, w * budget // total) for w in cols]
        new_cols[-1] += budget - sum(new_cols)
        new_total = sum(new_cols)
        new_grid = (
            '<w:tblGrid>'
            + ''.join(f'<w:gridCol w:w="{w}" />' for w in new_cols)
            + '</w:tblGrid>'
        )
        body = body[:grid_match.start()] + new_grid + body[grid_match.end():]
        # Replace <w:tblW> with an explicit dxa width so Word doesn't expand
        # the table to 100% of the parent (which ignores the indent offset).
        body = TBL_W_RE.sub(
            f'<w:tblW w:w="{new_total}" w:type="dxa" />', body, count=1,
        )
        if '<w:tblStyle w:val="horizontal" />' not in body:
            ind_tag = (f'<w:tblInd w:w="{indent + TBL_CELL_SIDE_MARGIN}" '
                       f'w:type="dxa" />')
            if ind_match:
                body = TBL_IND_RE.sub(ind_tag, body, count=1)
            else:
                body = body.replace(
                    f'<w:tblW w:w="{new_total}" w:type="dxa" />',
                    f'<w:tblW w:w="{new_total}" w:type="dxa" />' + ind_tag,
                    1)
        def scale_tc(m: 're.Match[str]') -> str:
            return f'<w:tcW w:w="{int(m.group(1)) * budget // total}" w:type="dxa" />'
        body = TC_W_RE.sub(scale_tc, body)
        return body
    return TABLE_RE.sub(fix, document_xml)


# ============================================================================
# document.xml -- inline image sizing
# ============================================================================
#
# Pandoc carries through the source bitmap's pixel dimensions, so a screenshot
# wider than the page text area overflows the right margin. Cap each inline
# drawing at usable_text_width minus the host paragraph's left indent so the
# image's right edge lines up with body text. Height is scaled to preserve
# the aspect ratio. The indent is read from <w:ind> on the paragraph or, when
# absent, from the level definition of the numbering the paragraph points at,
# so an image inside a deep nested list still ends flush with surrounding text.

PARA_IND_LEFT_RE = re.compile(r'<w:ind\b[^/>]*\bw:left="(\d+)"')
PARA_PPR_RE = re.compile(r'<w:pPr\b[^>]*>(.*?)</w:pPr>', re.DOTALL)
PARA_NUMPR_RE = re.compile(r'<w:numPr>(.*?)</w:numPr>', re.DOTALL)
PARA_ILVL_RE = re.compile(r'<w:ilvl w:val="(\d+)"')
PARA_NUMID_RE = re.compile(r'<w:numId w:val="(\d+)"')
WP_EXTENT_RE = re.compile(r'<wp:extent\s+cx="(\d+)"\s+cy="(\d+)"\s*/>')
A_EXT_RE = re.compile(r'<a:ext\s+cx="(\d+)"\s+cy="(\d+)"\s*/>')

NumberingIndex = Dict[str, List[int]]
NumberingLayout = Dict[str, List['tuple[int, int]']]


def _build_numbering_index(numbering_xml: str) -> NumberingIndex:
    """Map each w:numId to the list of left-indent dxa values per ilvl."""
    abstract_indents: Dict[str, List[int]] = {}
    for am in re.finditer(
        r'<w:abstractNum w:abstractNumId="(\d+)">(.*?)</w:abstractNum>',
        numbering_xml, re.DOTALL,
    ):
        aid, body = am.group(1), am.group(2)
        levels: List[int] = []
        for lvl in re.finditer(r'<w:lvl w:ilvl="(\d+)">(.*?)</w:lvl>', body, re.DOTALL):
            ilvl = int(lvl.group(1))
            ind_m = PARA_IND_LEFT_RE.search(lvl.group(2))
            indent = int(ind_m.group(1)) if ind_m else 0
            while len(levels) <= ilvl:
                levels.append(0)
            levels[ilvl] = indent
        abstract_indents[aid] = levels

    num_to_indents: NumberingIndex = {}
    for nm in re.finditer(
        r'<w:num w:numId="(\d+)">(.*?)</w:num>',
        numbering_xml, re.DOTALL,
    ):
        nid, body = nm.group(1), nm.group(2)
        am_m = re.search(r'<w:abstractNumId w:val="(\d+)"\s*/>', body)
        if am_m:
            num_to_indents[nid] = abstract_indents.get(am_m.group(1), [])
    return num_to_indents


def _build_numbering_layout(numbering_xml: str) -> NumberingLayout:
    """Map numId levels to their text-left and hanging-indent values."""
    abstract_layouts: Dict[str, List['tuple[int, int]']] = {}
    for match in re.finditer(
        r'<w:abstractNum w:abstractNumId="(\d+)">(.*?)</w:abstractNum>',
        numbering_xml,
        re.DOTALL,
    ):
        levels: List['tuple[int, int]'] = []
        for level_match in re.finditer(
            r'<w:lvl w:ilvl="(\d+)">(.*?)</w:lvl>',
            match.group(2),
            re.DOTALL,
        ):
            level = int(level_match.group(1))
            indent = PARA_IND_LEFT_RE.search(level_match.group(2))
            hanging = re.search(r'<w:ind\b[^/>]*\bw:hanging="(\d+)"',
                                level_match.group(2))
            value = (int(indent.group(1)) if indent else 0,
                     int(hanging.group(1)) if hanging else 0)
            while len(levels) <= level:
                levels.append((0, 0))
            levels[level] = value
        abstract_layouts[match.group(1)] = levels

    result: NumberingLayout = {}
    for match in re.finditer(
        r'<w:num w:numId="(\d+)">(.*?)</w:num>', numbering_xml, re.DOTALL,
    ):
        abstract = re.search(
            r'<w:abstractNumId w:val="(\d+)" />', match.group(2))
        if abstract:
            result[match.group(1)] = abstract_layouts.get(
                abstract.group(1), [])
    return result


def _paragraph_indent(paragraph_xml: str, numbering: NumberingIndex) -> int:
    ppr_m = PARA_PPR_RE.search(paragraph_xml)
    if not ppr_m:
        return 0
    ppr_body = ppr_m.group(1)
    direct = PARA_IND_LEFT_RE.search(ppr_body)
    if direct:
        return int(direct.group(1))
    num_m = PARA_NUMPR_RE.search(ppr_body)
    if not num_m:
        return 0
    ilvl_m = PARA_ILVL_RE.search(num_m.group(1))
    numid_m = PARA_NUMID_RE.search(num_m.group(1))
    if not (ilvl_m and numid_m):
        return 0
    ilvl = int(ilvl_m.group(1))
    indents = numbering.get(numid_m.group(1), [])
    return indents[ilvl] if ilvl < len(indents) else 0


def _continuation_num_ids(numbering_xml: str) -> set:
    """Return numIds whose levels carry Pandoc's invisible list marker."""
    abstract_ids = set()
    for match in re.finditer(
        r'<w:abstractNum\b[^>]*w:abstractNumId="(\d+)"[^>]*>'
        r'(.*?)</w:abstractNum>',
        numbering_xml,
        re.DOTALL,
    ):
        body = match.group(2)
        first_level = re.search(
            r'<w:lvl w:ilvl="0">(.*?)</w:lvl>', body, re.DOTALL)
        if first_level and '<w:lvlText w:val=" " />' in first_level.group(1):
            abstract_ids.add(match.group(1))

    num_ids = set()
    for match in re.finditer(
        r'<w:num w:numId="(\d+)">(.*?)</w:num>', numbering_xml, re.DOTALL,
    ):
        abstract = re.search(
            r'<w:abstractNumId w:val="(\d+)" />', match.group(2))
        if abstract and abstract.group(1) in abstract_ids:
            num_ids.add(match.group(1))
    return num_ids


def _paragraph_list_ref(paragraph_xml: str) -> 'tuple[int, str] | None':
    ppr_match = PARA_PPR_RE.search(paragraph_xml)
    if not ppr_match:
        return None
    num_match = PARA_NUMPR_RE.search(ppr_match.group(1))
    if not num_match:
        return None
    level = PARA_ILVL_RE.search(num_match.group(1))
    num_id = PARA_NUMID_RE.search(num_match.group(1))
    if not (level and num_id):
        return None
    return int(level.group(1)), num_id.group(1)


IND_TAG_RE = re.compile(r'<w:ind\b[^/]*/>')
TABS_TAG_RE = re.compile(r'<w:tabs>.*?</w:tabs>', re.DOTALL)
IND_LATE_PPR_TAG_RE = re.compile(
    r'<w:(?:contextualSpacing|mirrorIndents|suppressOverlap|jc|textDirection'
    r'|textAlignment|textboxTightWrap|outlineLvl|divId|cnfStyle|rPr|sectPr'
    r'|pPrChange)\b')


def _continuation_direct_indent(paragraph_xml: str, left: int) -> str:
    """Turn an invisible-marker list paragraph into a plain aligned one."""
    ppr_match = PARA_PPR_RE.search(paragraph_xml)
    if not ppr_match:
        return paragraph_xml
    ppr = ppr_match.group(0)
    ppr = PARA_NUMPR_RE.sub('', ppr, count=1)
    ppr = IND_TAG_RE.sub('', ppr)
    indent = f'<w:ind w:left="{left}" />'
    late = IND_LATE_PPR_TAG_RE.search(ppr)
    insert_at = late.start() if late else ppr.rfind('</w:pPr>')
    ppr = ppr[:insert_at] + indent + ppr[insert_at:]
    return (paragraph_xml[:ppr_match.start()] + ppr
            + paragraph_xml[ppr_match.end():])


def _numbered_paragraph_direct_layout(
    paragraph_xml: str,
    left: int,
    hanging: int,
) -> str:
    """Pin the list text and marker columns in the paragraph properties."""
    ppr_match = PARA_PPR_RE.search(paragraph_xml)
    if not ppr_match:
        return paragraph_xml
    ppr = ppr_match.group(0)
    ppr = TABS_TAG_RE.sub('', ppr)
    ppr = IND_TAG_RE.sub('', ppr)
    num_match = PARA_NUMPR_RE.search(ppr)
    if not num_match:
        return paragraph_xml
    tabs = f'<w:tabs><w:tab w:val="num" w:pos="{left}" /></w:tabs>'
    ppr = ppr[:num_match.end()] + tabs + ppr[num_match.end():]
    spacing = re.search(r'<w:spacing\b[^/]*/>', ppr)
    insert_at = spacing.end() if spacing else num_match.end() + len(tabs)
    indent = f'<w:ind w:left="{left}" w:hanging="{hanging}" />'
    ppr = ppr[:insert_at] + indent + ppr[insert_at:]
    return (paragraph_xml[:ppr_match.start()] + ppr
            + paragraph_xml[ppr_match.end():])


def _make_align_list_continuations(
    numbering: NumberingIndex,
    layouts: NumberingLayout,
    continuation_num_ids: set,
) -> XmlTransform:
    """Align continuation text with its numbered paragraph's text column."""
    def _align(document_xml: str) -> str:
        pieces: List[str] = []
        position = 0
        active_left_by_level: Dict[int, int] = {}
        for match in PARAGRAPH_RE.finditer(document_xml):
            pieces.append(document_xml[position:match.start()])
            paragraph = match.group(0)
            ref = _paragraph_list_ref(paragraph)
            if ref:
                level, num_id = ref
                if num_id in continuation_num_ids:
                    left = active_left_by_level.get(level)
                    if left is not None:
                        paragraph = _continuation_direct_indent(paragraph, left)
                else:
                    levels = layouts.get(num_id, [])
                    if level < len(levels) and not HEADING_PSTYLE_RE.search(paragraph):
                        left, hanging = levels[level]
                        paragraph = _numbered_paragraph_direct_layout(
                            paragraph, left, hanging)
                    active_left_by_level = {
                        key: value
                        for key, value in active_left_by_level.items()
                        if key < level
                    }
                    active_left_by_level[level] = _paragraph_indent(
                        paragraph, numbering)
            elif any(text.strip() for text in TEXT_RUN_RE.findall(paragraph)):
                active_left_by_level = {}
            pieces.append(paragraph)
            position = match.end()
        pieces.append(document_xml[position:])
        return ''.join(pieces)
    return _align


def _make_resize_images(numbering: NumberingIndex) -> XmlTransform:
    def _resize_images(document_xml: str) -> str:
        def fix(match: 're.Match[str]') -> str:
            para = match.group(0)
            if '<w:drawing' not in para:
                return para
            indent = _paragraph_indent(para, numbering)
            budget_dxa = USABLE_TEXT_WIDTH_DXA - indent
            if budget_dxa <= 0:
                return para
            budget_emu = budget_dxa * EMU_PER_DXA

            def scale(m: 're.Match[str]', tag: str) -> str:
                cx, cy = int(m.group(1)), int(m.group(2))
                if cx <= budget_emu:
                    return m.group(0)
                new_cy = cy * budget_emu // cx
                return f'<{tag} cx="{budget_emu}" cy="{new_cy}" />'

            para = WP_EXTENT_RE.sub(lambda m: scale(m, 'wp:extent'), para)
            para = A_EXT_RE.sub(lambda m: scale(m, 'a:ext'), para)
            return para
        return PARAGRAPH_RE.sub(fix, document_xml)
    return _resize_images


# ============================================================================
# document.xml -- symmetric table cells
# ============================================================================
#
# A table cell's paragraphs carry no style, so the document default
# `w:after="200"` hangs under the last line while the cell's top margin is
# zero: the text hugs the top border and floats 10pt over the bottom one.
# Zeroing the first paragraph's space-before and the last paragraph's
# space-after leaves both edges to the cell margins, which are equal.
# Paragraphs between the first and last keep their spacing, so a
# multi-paragraph cell still separates its paragraphs. Bibliography
# metadata tables (`horizontal` style) have their own compaction pass
# below and are skipped here.

CELL_TBL_RE = re.compile(r'<w:tbl>.*?</w:tbl>', re.DOTALL)
CELL_TC_RE = re.compile(r'<w:tc>.*?</w:tc>', re.DOTALL)
CELL_P_RE = re.compile(r'<w:p\b[^>]*/>|<w:p\b[^>]*>.*?</w:p>', re.DOTALL)
CELL_PPR_RE = re.compile(r'<w:pPr\b[^>]*>.*?</w:pPr>|<w:pPr\b[^>]*/>',
                         re.DOTALL)


def _set_edge_spacing(p_xml: str, attr: str, value: str) -> str:
    spacing_frag = f'<w:spacing w:{attr}="{value}" />'
    empty_p = re.match(r'<w:p\b([^>]*)/>$', p_xml, re.DOTALL)
    if empty_p:
        return f'<w:p{empty_p.group(1)}><w:pPr>{spacing_frag}</w:pPr></w:p>'
    ppr = CELL_PPR_RE.search(p_xml)
    if ppr is None or ppr.group(0).endswith('/>'):
        open_end = p_xml.find('>') + 1
        return (p_xml[:open_end] + f'<w:pPr>{spacing_frag}</w:pPr>'
                + p_xml[open_end:])
    seg = ppr.group(0)
    spacing = re.search(r'<w:spacing\b[^/]*/>', seg)
    if spacing is None:
        # CT_PPr is a strict sequence: w:spacing sits after w:pStyle and
        # w:numPr; inserting it earlier makes consumers drop it.
        insert_at = seg.find('>') + 1
        for pat in (r'<w:pStyle\b[^/]*/>', r'</w:numPr>'):
            anchor = re.search(pat, seg)
            if anchor:
                insert_at = max(insert_at, anchor.end())
        new_seg = seg[:insert_at] + spacing_frag + seg[insert_at:]
    elif f'w:{attr}=' in spacing.group(0):
        new_seg = seg.replace(
            spacing.group(0),
            re.sub(rf'w:{attr}="\d+"', f'w:{attr}="{value}"',
                   spacing.group(0)), 1)
    else:
        new_seg = seg.replace(
            spacing.group(0),
            spacing.group(0)[:-2] + f'w:{attr}="{value}" />', 1)
    return p_xml.replace(seg, new_seg, 1)


def _symmetric_table_cells(document_xml: str) -> str:
    def fix_tc(match: 're.Match[str]') -> str:
        tc = match.group(0)
        paragraphs = list(CELL_P_RE.finditer(tc))
        if not paragraphs:
            return tc
        last = paragraphs[-1]
        tc = (tc[:last.start()]
              + _set_edge_spacing(last.group(0), 'after', '0')
              + tc[last.end():])
        first = CELL_P_RE.search(tc)
        return (tc[:first.start()]
                + _set_edge_spacing(first.group(0), 'before', '0')
                + tc[first.end():])

    def fix_tbl(match: 're.Match[str]') -> str:
        tbl = match.group(0)
        if '<w:tblStyle w:val="horizontal" />' in tbl:
            return tbl
        return CELL_TC_RE.sub(fix_tc, tbl)

    return CELL_TBL_RE.sub(fix_tbl, document_xml)


# ============================================================================
# document.xml -- compact lists inside table cells
# ============================================================================
#
# List items inherit the Normal style's 200-twip space-after. That spacing is
# useful between body paragraphs, but inside a table it creates a blank line
# between every bullet and makes checklist cells unnecessarily tall. Apply
# zero before/after spacing only to numbered or bulleted paragraphs inside
# ordinary table cells. Lists outside tables keep their normal spacing.


def _compact_table_cell_lists(document_xml: str) -> str:
    def compact_paragraph(match: 're.Match[str]') -> str:
        paragraph = match.group(0)
        if '<w:numPr>' not in paragraph:
            return paragraph
        paragraph = _set_edge_spacing(paragraph, 'before', '0')
        return _set_edge_spacing(paragraph, 'after', '0')

    def compact_cell(match: 're.Match[str]') -> str:
        return CELL_P_RE.sub(compact_paragraph, match.group(0))

    def compact_table(match: 're.Match[str]') -> str:
        table = match.group(0)
        if '<w:tblStyle w:val="horizontal" />' in table:
            return table
        return CELL_TC_RE.sub(compact_cell, table)

    return CELL_TBL_RE.sub(compact_table, document_xml)


# ============================================================================
# document.xml -- symmetric space around tables
# ============================================================================
#
# The gap over a table is the preceding paragraph's space-after (the
# document default of 200 twips), but the paragraph under a table is a list
# item or plain paragraph whose space-before is zero, so the table hugs
# what follows it. Give the paragraph on each side of a table the same 200
# on its table-facing edge. Headings keep their own larger spacing, and
# bibliography metadata tables (`horizontal` style) have their own gap
# pass below.

TABLE_GAP = "200"  # the docDefaults space-after that forms the gap above
_P_CHUNK = r'<w:p\b[^>]*>(?:(?!</w:p>).)*?</w:p>'
P_BEFORE_TBL_RE = re.compile('(' + _P_CHUNK + r')(?=\s*<w:tbl>)', re.DOTALL)
P_AFTER_TBL_RE = re.compile(r'(</w:tbl>\s*)(' + _P_CHUNK + ')', re.DOTALL)
HORIZONTAL_TBL_MARKER = '<w:tblStyle w:val="horizontal" />'


def _tbl_at_is_horizontal(document_xml: str, tbl_start: int) -> bool:
    tblpr_end = document_xml.find('</w:tblPr>', tbl_start)
    if tblpr_end == -1:
        return False
    return HORIZONTAL_TBL_MARKER in document_xml[tbl_start:tblpr_end]


def _symmetric_table_margins(document_xml: str) -> str:
    def pad_before(match: 're.Match[str]') -> str:
        p_xml = match.group(1)
        if 'w:pStyle w:val="Heading' in p_xml:
            return p_xml
        if _tbl_at_is_horizontal(document_xml, match.end()):
            return p_xml
        return _set_edge_spacing(p_xml, 'after', TABLE_GAP)

    def pad_after(match: 're.Match[str]') -> str:
        p_xml = match.group(2)
        if 'w:pStyle w:val="Heading' in p_xml:
            return match.group(0)
        tbl_start = document_xml.rfind('<w:tbl>', 0, match.start())
        if tbl_start != -1 and _tbl_at_is_horizontal(document_xml,
                                                     tbl_start):
            return match.group(0)
        return match.group(1) + _set_edge_spacing(p_xml, 'before',
                                                  TABLE_GAP)

    document_xml = P_BEFORE_TBL_RE.sub(pad_before, document_xml)
    return P_AFTER_TBL_RE.sub(pad_after, document_xml)


# ============================================================================
# document.xml -- source-fields tables
# ============================================================================
#
# A bibliography entry's metadata block (`[horizontal.source-fields]` in the
# AsciiDoc source) arrives from the DocBook path as a two-column table whose
# style name carries the dlist style: <w:tblStyle w:val="horizontal" />. The
# block is a machine-facing record and must recede behind the prose the way
# the HTML and PDF exports render it: no borders, tight rows, small muted
# type, bold terms. Word applies whatever the undefined "horizontal" style
# falls back to (a bordered grid at body size), so the record's look is
# forced here with direct formatting, which always outranks a table style.

SF_TABLE_MARKER = '<w:tblStyle w:val="horizontal" />'
SF_RUN_PROPS = (
    '<w:color w:val="595959" /><w:sz w:val="15" /><w:szCs w:val="15" />'
)
SF_BORDERS_AND_MARGINS = (
    '<w:tblBorders>'
    '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto" />'
    '</w:tblBorders>'
)
SF_CELL_MARGINS = (
    '<w:tblCellMar>'
    '<w:top w:w="0" w:type="dxa" /><w:left w:w="0" w:type="dxa" />'
    '<w:bottom w:w="15" w:type="dxa" /><w:right w:w="115" w:type="dxa" />'
    '</w:tblCellMar>'
)
SF_PARA_SPACING = (
    '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />'
)
SF_TR_RE = re.compile(r'<w:tr>.*?</w:tr>', re.DOTALL)
SF_TC_RE = re.compile(r'<w:tc>.*?</w:tc>', re.DOTALL)
SF_PSTYLE_RE = re.compile(r'(<w:pPr><w:pStyle w:val="[^"]+" />)(</w:pPr>)?')


def _compact_source_fields_tables(document_xml: str) -> str:
    def compact(match: 're.Match[str]') -> str:
        body = match.group(0)
        if SF_TABLE_MARKER not in body or SF_RUN_PROPS in body:
            return body
        # Borderless, with hairline cell margins; both slot into tblPr at
        # their schema positions (borders after tblInd, margins after
        # tblLayout).
        body = body.replace('<w:tblLayout w:type="fixed" />',
                            SF_BORDERS_AND_MARGINS
                            + '<w:tblLayout w:type="fixed" />'
                            + SF_CELL_MARGINS, 1)
        # Tight paragraphs: explicit spacing overrides the style's own.
        body = SF_PSTYLE_RE.sub(
            lambda m: m.group(1) + SF_PARA_SPACING + (m.group(2) or ''),
            body)
        # Small muted runs: append into existing run properties, wrap the
        # bare runs.
        body = body.replace('</w:rPr>', SF_RUN_PROPS + '</w:rPr>')
        body = re.sub(r'<w:r>(?=<w:t)',
                      '<w:r><w:rPr>' + SF_RUN_PROPS + '</w:rPr>', body)
        # Bold terms: every run of each row's first cell.
        def embolden_row(row_match: 're.Match[str]') -> str:
            row = row_match.group(0)
            cell_match = SF_TC_RE.search(row)
            if not cell_match:
                return row
            cell = cell_match.group(0).replace(
                '<w:rPr>', '<w:rPr><w:b />')
            return row[:cell_match.start()] + cell + row[cell_match.end():]
        body = SF_TR_RE.sub(embolden_row, body)
        return body
    return _equalize_source_fields_gaps(TABLE_RE.sub(compact, document_xml))


# The gap above the record (the entry label's spacing-after) and the gap
# below it (the next label's spacing-before, which Word defaults to zero)
# must match. Both neighbors of every source-fields table get one explicit
# spacing element; a label sitting between two tables receives it once.
SF_GAP_SPACING = '<w:spacing w:before="120" w:after="120" />'
SF_ADJACENT_PARA_RE = re.compile(
    r'<w:p><w:pPr>((?:(?!</w:p>).)*?)</w:pPr>((?:(?!</w:p>).)*?)</w:p>(\s*)$',
    re.DOTALL)
SF_FOLLOWING_PARA_RE = re.compile(
    r'^(\s*)<w:p><w:pPr>((?:(?!</w:p>).)*?)(</w:pPr>)', re.DOTALL)


def _equalize_source_fields_gaps(document_xml: str) -> str:
    pieces: List[str] = []
    pos = 0
    patch_following = False

    def patch_leading(segment: str) -> str:
        match = SF_FOLLOWING_PARA_RE.search(segment)
        if not match or SF_GAP_SPACING in match.group(2):
            return segment
        return (segment[:match.end(2)] + SF_GAP_SPACING
                + segment[match.end(2):])

    def patch_trailing(segment: str) -> str:
        match = SF_ADJACENT_PARA_RE.search(segment)
        if not match or SF_GAP_SPACING in match.group(1):
            return segment
        insert_at = match.start(1) + len(match.group(1))
        return segment[:insert_at] + SF_GAP_SPACING + segment[insert_at:]

    for table_match in TABLE_RE.finditer(document_xml):
        segment = document_xml[pos:table_match.start()]
        if patch_following:
            segment = patch_leading(segment)
        body = table_match.group(0)
        if SF_TABLE_MARKER in body:
            segment = patch_trailing(segment)
            patch_following = True
        else:
            patch_following = False
        pieces.append(segment)
        pieces.append(body)
        pos = table_match.end()
    tail = document_xml[pos:]
    if patch_following:
        tail = patch_leading(tail)
    pieces.append(tail)
    return ''.join(pieces)


# ============================================================================
# document.xml -- table cell justification
# ============================================================================
#
# Normal is justified, so body prose fills the measure. Pandoc nevertheless
# writes an explicit <w:jc w:val="left"/> on every table-cell paragraph,
# derived from the column alignment, and that override makes a prose cell read
# ragged beside the justified prose around it. Promote the default left
# alignment to justified inside tables. Four cases keep their alignment: a
# cell the author aligned right or centre, a code paragraph (left for the
# reason in _left_align_source_code), a source-fields record, whose
# machine-facing paths and digests shouldn't be stretched across the column,
# and a bold paragraph. The last one stands in for a header column (`h` in the
# AsciiDoc column spec), which arrives here carrying no marker of its own
# beyond the bold run Pandoc gives it. Such a cell holds a label, and a label
# that wraps would have its words spread across the column.

CELL_PARA_RE = re.compile(r'<w:p\b.*?</w:p>', re.DOTALL)
JC_LEFT_RE = re.compile(r'<w:jc w:val="left"\s*/>')
BOLD_RUN_RE = re.compile(r'<w:b\s*/>')


def _justify_table_cells(document_xml: str) -> str:
    def justify_table(match: 're.Match[str]') -> str:
        body = match.group(0)
        if SF_TABLE_MARKER in body:
            return body

        def justify_para(para_match: 're.Match[str]') -> str:
            para = para_match.group(0)
            if 'w:val="SourceCode"' in para or BOLD_RUN_RE.search(para):
                return para
            return JC_LEFT_RE.sub('<w:jc w:val="both" />', para)

        return CELL_PARA_RE.sub(justify_para, body)
    return TABLE_RE.sub(justify_table, document_xml)


# ============================================================================
# Pipeline
# ============================================================================
#
# Map each DOCX part to the ordered list of transforms to apply to it.
# Order matters within a list: e.g. _strip_empty_headings must run before
# _force_a4_section keeps inserting pgSz tags, and the heading numbering
# transform must run before ordered-list unification so the heading
# abstractNum is already present when ordered abstracts are scanned.

TRANSFORMS: Dict[str, List[XmlTransform]] = {
    'word/numbering.xml': [
        _declare_compat_namespaces,
        _inject_heading_numbering,
        _unify_ordered_lists,
        _align_bullet_lists,
    ],
    'word/styles.xml': [
        _left_align_source_code,
        _compact_footnotes,
        _symmetric_heading_spacing,
    ],
    'word/footnotes.xml': [
        _space_after_footnote_number,
        _align_footnote_continuations,
        _highlight_placeholders,
    ],
    'word/document.xml': [
        _separate_author_email,
        _strip_empty_headings,
        _keep_paragraph_headers_with_body,
        _highlight_placeholders,
        _force_a4_section,
        _fit_table_widths,
        _symmetric_table_cells,
        _compact_table_cell_lists,
        _symmetric_table_margins,
        _compact_source_fields_tables,
        _justify_table_cells,
    ],
}


def _patch_part(tmp_root: str, rel_path: str, transforms: List[XmlTransform]) -> None:
    path = os.path.join(tmp_root, *rel_path.split('/'))
    if not os.path.exists(path):  # e.g. footnotes.xml in a footnote-free doc
        return
    with open(path, encoding='utf-8') as f:
        xml = f.read()
    for transform in transforms:
        xml = transform(xml)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(xml)


def main(docx_path: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(docx_path) as zf:
            zf.extractall(tmp)
        # Patch numbering.xml first so image sizing can read the final
        # per-level indents when resolving paragraph indents.
        _patch_part(tmp, 'word/numbering.xml', TRANSFORMS['word/numbering.xml'])
        with open(os.path.join(tmp, 'word', 'numbering.xml'), encoding='utf-8') as f:
            numbering_xml = f.read()
        numbering_index = _build_numbering_index(numbering_xml)
        numbering_layout = _build_numbering_layout(numbering_xml)
        continuation_num_ids = _continuation_num_ids(numbering_xml)
        # Collect anchors referenced anywhere so unreferenced bookmarks can
        # be dropped while cross-reference targets survive.
        part_xmls = []
        for rel_path in ('word/document.xml', 'word/footnotes.xml',
                         'word/endnotes.xml'):
            path = os.path.join(tmp, *rel_path.split('/'))
            if os.path.exists(path):
                with open(path, encoding='utf-8') as f:
                    part_xmls.append(f.read())
        referenced_anchors = _collect_referenced_anchors(part_xmls)
        for rel_path, transforms in TRANSFORMS.items():
            if rel_path == 'word/numbering.xml':
                continue
            extra = (
                [_make_align_list_continuations(
                     numbering_index, numbering_layout, continuation_num_ids),
                 _make_resize_images(numbering_index),
                 _make_strip_bookmarks(referenced_anchors)]
                if rel_path == 'word/document.xml' else []
            )
            _patch_part(tmp, rel_path, transforms + extra)
        out_tmp = docx_path + '.tmp'
        with zipfile.ZipFile(out_tmp, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(tmp):
                for name in files:
                    full = os.path.join(root, name)
                    arc = os.path.relpath(full, tmp)
                    zf.write(full, arc)
        shutil.move(out_tmp, docx_path)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: apply_docx_formatting.py <path-to-docx>')
    main(sys.argv[1])
