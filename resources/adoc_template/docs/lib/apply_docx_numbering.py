#!/usr/bin/env python3
"""Inject native Word multilevel heading numbering into a Pandoc-generated DOCX.

Pandoc rebuilds word/numbering.xml from scratch when converting, so the
multilevel list definition cannot live solely in the reference DOCX. The
reference DOCX binds Heading1-6 styles to numId=9001 (a value above Pandoc's
auto-assigned range); this script adds the matching <w:abstractNum> and
<w:num> entries so Word renders 1, 1.1, 1.1.1, ... and renumbers
automatically when sections are added or removed.

Usage: python3 apply_docx_numbering.py <path-to-docx>
"""
import os
import shutil
import sys
import tempfile
import zipfile

ABSTRACT_NUM_ID = "9991"
NUM_ID = "9001"
NSID = "170cd2df"  # distinctive marker for idempotency check

LEVELS = []
for i in range(9):
    pstyle = f'<w:pStyle w:val="Heading{i+1}" />' if i < 6 else ''
    lvl_text = '.'.join(f'%{j+1}' for j in range(i + 1))
    ind_left = i * 360
    LEVELS.append(
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

ABSTRACT_NUM = (
    f'<w:abstractNum w:abstractNumId="{ABSTRACT_NUM_ID}">'
    f'<w:nsid w:val="{NSID}" />'
    f'<w:multiLevelType w:val="multilevel" />'
    f'<w:tmpl w:val="00000001" />'
    + ''.join(LEVELS) +
    f'</w:abstractNum>'
)
NUM = f'<w:num w:numId="{NUM_ID}"><w:abstractNumId w:val="{ABSTRACT_NUM_ID}" /></w:num>'


def inject(numbering_xml: str) -> str:
    # Idempotency check: look for our distinctive nsid, not just the abstractNumId
    # (Pandoc dynamically allocates abstractNumIds and may reuse common values).
    if f'<w:nsid w:val="{NSID}" />' in numbering_xml:
        return numbering_xml  # already applied
    insertion_point = numbering_xml.find('<w:abstractNum ')
    if insertion_point == -1:
        # No existing abstractNum: place both right after the opening tag.
        open_tag_end = numbering_xml.find('>', numbering_xml.find('<w:numbering')) + 1
        return (
            numbering_xml[:open_tag_end]
            + ABSTRACT_NUM + NUM
            + numbering_xml[open_tag_end:]
        )
    patched = (
        numbering_xml[:insertion_point]
        + ABSTRACT_NUM
        + numbering_xml[insertion_point:]
    )
    return patched.replace('</w:numbering>', NUM + '</w:numbering>')


def main(docx_path: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(docx_path) as zf:
            zf.extractall(tmp)
        numbering_path = os.path.join(tmp, 'word', 'numbering.xml')
        with open(numbering_path, encoding='utf-8') as f:
            numbering = f.read()
        patched = inject(numbering)
        with open(numbering_path, 'w', encoding='utf-8') as f:
            f.write(patched)
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
