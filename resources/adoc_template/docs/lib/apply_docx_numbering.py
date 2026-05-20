#!/usr/bin/env python3
"""Inject native Word multilevel numbering into a Pandoc-generated DOCX.

Pandoc rebuilds word/numbering.xml from scratch when converting, so the
multilevel list definitions cannot live solely in the reference DOCX. This
script patches the regenerated numbering.xml in two ways:

1. Heading numbering. The reference DOCX binds Heading1-6 styles to
   numId=9001; this script adds the matching multilevel abstractNum so Word
   renders 1, 1.1, 1.1.1, ... and renumbers when sections are added or
   removed.

2. Ordered-list numbering. Pandoc emits each nesting level of an ordered
   list as a separate single-format abstract (one for decimal, one for
   lowerLetter, etc.), so Word treats them as disconnected lists. When the
   author edits a list manually, Word picks its own scheme for the new
   level. This script defines one 9-level multilevel ordered-list abstract
   matching Asciidoctor's default (decimal, lowerLetter, lowerRoman,
   upperLetter, upperRoman, then cycle) and remaps every ordered-list
   <w:num> to point at it. Each <w:num> keeps its own startOverride entries,
   so independent lists still restart at 1 / a / i / A / I.

Usage: python3 apply_docx_numbering.py <path-to-docx>
"""
import os
import re
import shutil
import sys
import tempfile
import zipfile

# Heading multilevel numbering ------------------------------------------------

HEADING_ABSTRACT_NUM_ID = "9991"
HEADING_NUM_ID = "9001"
HEADING_NSID = "170cd2df"  # distinctive marker for idempotency check

_heading_levels = []
for i in range(9):
    pstyle = f'<w:pStyle w:val="Heading{i+1}" />' if i < 6 else ''
    lvl_text = '.'.join(f'%{j+1}' for j in range(i + 1))
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

# Ordered-list multilevel numbering ------------------------------------------
#
# Mirrors Asciidoctor's default signifier sequence so DOCX matches HTML/PDF
# and so manual edits in Word (Tab/Shift-Tab to change level, split a list)
# stay aligned with the same scheme.

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

# Author paragraph separator -------------------------------------------------
#
# Pandoc joins the AsciiDoc :author: and :email: with a single space, so the
# byline renders as "Firstname Lastname email@host". Insert " | " before the
# email so the byline reads "Firstname Lastname | email@host".

AUTHOR_PARA_RE = re.compile(
    r'<w:p>\s*<w:pPr>\s*<w:pStyle w:val="Author"\s*/>\s*</w:pPr>.*?</w:p>',
    re.DOTALL,
)
EMAIL_SEP_RE = re.compile(r' ([\w.+\-]+@[\w.\-]+)')


def _inject_heading(numbering_xml: str) -> str:
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


def patch(numbering_xml: str) -> str:
    return _unify_ordered_lists(_inject_heading(numbering_xml))


def _separate_author_email(document_xml: str) -> str:
    def fix(match: 're.Match[str]') -> str:
        para = match.group(0)
        if ' | ' in para:
            return para
        return EMAIL_SEP_RE.sub(r' | \1', para, count=1)
    return AUTHOR_PARA_RE.sub(fix, document_xml)


def main(docx_path: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(docx_path) as zf:
            zf.extractall(tmp)
        numbering_path = os.path.join(tmp, 'word', 'numbering.xml')
        with open(numbering_path, encoding='utf-8') as f:
            numbering = f.read()
        patched = patch(numbering)
        with open(numbering_path, 'w', encoding='utf-8') as f:
            f.write(patched)
        document_path = os.path.join(tmp, 'word', 'document.xml')
        with open(document_path, encoding='utf-8') as f:
            document = f.read()
        document = _separate_author_email(document)
        with open(document_path, 'w', encoding='utf-8') as f:
            f.write(document)
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
        sys.exit('Usage: apply_docx_numbering.py <path-to-docx>')
    main(sys.argv[1])
