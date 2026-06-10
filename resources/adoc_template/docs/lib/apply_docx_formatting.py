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
# numbering.xml — heading multilevel numbering
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
    ind_left = i * 360
    _heading_levels.append(
        f'<w:lvl w:ilvl="{i}">'
        f'<w:start w:val="1" />'
        f'<w:numFmt w:val="decimal" />'
        f'{pstyle}'
        f'<w:suff w:val="tab" />'
        f'<w:lvlText w:val="{lvl_text}" />'
        f'<w:lvlJc w:val="left" />'
        f'<w:pPr><w:ind w:left="{ind_left}" w:firstLine="0" /></w:pPr>'
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
# numbering.xml — ordered-list multilevel numbering
# ============================================================================
#
# Pandoc emits each nesting level of an ordered list as a separate
# single-format abstract (one for decimal, one for lowerLetter, etc.), so
# Word treats them as disconnected lists. When the author edits a list
# manually, Word picks its own scheme for the new level. This transform
# defines one 9-level multilevel ordered-list abstract matching
# Asciidoctor's default (decimal, lowerLetter, lowerRoman, upperLetter,
# upperRoman, then cycle) and remaps every ordered-list <w:num> to point
# at it. Each <w:num> keeps its own startOverride entries, so independent
# lists still restart at 1 / a / i / A / I.

ORDERED_ABSTRACT_NUM_ID = "9992"
ORDERED_NSID = "170cd2e0"  # distinctive marker for idempotency check

ORDERED_FORMATS = [
    "decimal", "lowerLetter", "lowerRoman", "upperLetter", "upperRoman",
    "decimal", "lowerLetter", "lowerRoman", "upperLetter",
]

_ordered_levels = []
for i, fmt in enumerate(ORDERED_FORMATS):
    ind_left = (i + 1) * 720
    _ordered_levels.append(
        f'<w:lvl w:ilvl="{i}">'
        f'<w:start w:val="1" />'
        f'<w:numFmt w:val="{fmt}" />'
        f'<w:suff w:val="tab" />'
        f'<w:lvlText w:val="%{i+1}." />'
        f'<w:lvlJc w:val="left" />'
        f'<w:pPr><w:ind w:left="{ind_left}" w:hanging="360" /></w:pPr>'
        f'</w:lvl>'
    )

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


def _unify_ordered_lists(numbering_xml: str) -> str:
    if f'<w:nsid w:val="{ORDERED_NSID}" />' in numbering_xml:
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
# styles.xml — SourceCode justification
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
# styles.xml — footnote size and paragraph spacing
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
# footnotes.xml — exactly one space after the footnote number
# ============================================================================
#
# The hanging indent of FootnoteText equals the natural width of
# "superscript number + one word space" (see the styles transform above),
# so the generated footnotes must read exactly "number, space, text" to
# sit on the vertical line — same as a footnote typed by hand later.
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
# document.xml — author/email separator
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
# document.xml — empty heading paragraphs
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
# document.xml — section-title bookmarks
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
# document.xml — A4 page size and margins
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
# document.xml — table widths
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

TABLE_RE = re.compile(r'<w:tbl>.*?</w:tbl>', re.DOTALL)
TBL_IND_RE = re.compile(r'<w:tblInd w:w="(\d+)" w:type="dxa"\s*/>')
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
        def scale_tc(m: 're.Match[str]') -> str:
            return f'<w:tcW w:w="{int(m.group(1)) * budget // total}" w:type="dxa" />'
        body = TC_W_RE.sub(scale_tc, body)
        return body
    return TABLE_RE.sub(fix, document_xml)


# ============================================================================
# document.xml — inline image sizing
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
        _inject_heading_numbering,
        _unify_ordered_lists,
    ],
    'word/styles.xml': [
        _left_align_source_code,
        _compact_footnotes,
    ],
    'word/footnotes.xml': [
        _space_after_footnote_number,
        _align_footnote_continuations,
    ],
    'word/document.xml': [
        _separate_author_email,
        _strip_empty_headings,
        _force_a4_section,
        _fit_table_widths,
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
            numbering_index = _build_numbering_index(f.read())
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
                [_make_resize_images(numbering_index),
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
