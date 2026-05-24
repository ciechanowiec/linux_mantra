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
        for rel_path, transforms in TRANSFORMS.items():
            _patch_part(tmp, rel_path, transforms)
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
