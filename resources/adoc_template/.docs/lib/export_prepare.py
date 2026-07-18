#!/usr/bin/env python3
"""Prepare an AsciiDoc document that cites sources for DOCX export.

The citation apparatus -- `footnote:id[<<bib-anchor>>, LOCATOR: "+QUOTE+"]`
citation footnotes resolved against a closed bibliography section marked
`[[sources]]` -- is written for the working copy and verified by
`adoc_lint.py`. The DOCX export needs a derived copy of the document: the
DocBook-to-Pandoc pipeline silently drops a `footnoteref` (verified
empirically: a `footnote:id[]` reuse loses its mark), which HTML and PDF
render fine. This tool expands each reuse into an anonymous full copy of
its footnote, and gives each citation `<<id>>` its reference label as
explicit link text so no backend has to resolve the anchor's reference
text. A document without citations passes through unchanged, so export
recipes can run this tool unconditionally.

The derived document is written beside the source as
`<name>.docx-compat.adoc` and its path is printed, so a recipe can export
it and delete it afterwards. The citation spans come from the same parsed
model the linter uses (`adoc_lint.source_analysis`), so the two tools can
never disagree about what a citation is.

Usage: python3 export_prepare.py --docx-compat <file.adoc>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adoc_lint as al  # noqa: E402  (needs the sys.path line above)


def docx_compat(lines, ana):
    body_by_id = {cf.id: cf.body for cf in ana.citations
                  if cf.id and not cf.is_reuse}
    reuse_spans = {}
    for cf in ana.citations:
        if cf.is_reuse and cf.id in body_by_id:
            reuse_spans.setdefault(cf.line, []).append(
                (cf.start_col, cf.end_col, cf.id))
    for num, spans in reuse_spans.items():
        text = lines[num - 1]
        for start, end, cite_id in sorted(spans, reverse=True):
            text = (text[:start - 1]
                    + f"footnote:[{body_by_id[cite_id]}]"
                    + text[end - 1:])
        lines[num - 1] = text

    label_by_id = {e.id: (e.label or e.id) for e in ana.entries}
    citation_lines = {cf.line for cf in ana.citations}
    for num in citation_lines:
        text = lines[num - 1]
        for bib_id, label in label_by_id.items():
            text = text.replace(f"<<{bib_id}>>", f"<<{bib_id},{label}>>")
        lines[num - 1] = text
    return lines


def main(argv):
    if len(argv) != 2 or argv[0] != "--docx-compat":
        sys.stderr.write(
            "Usage: export_prepare.py --docx-compat <file.adoc>\n")
        return 2
    _mode, path = argv
    if not os.path.isfile(path):
        sys.stderr.write(f"export_prepare: no such file: {path}\n")
        return 2

    doc = al.scan(path)
    ana = al.source_analysis(doc)
    lines = [ln.text for ln in doc.lines]
    lines = docx_compat(lines, ana)

    out_path = os.path.splitext(path)[0] + ".docx-compat.adoc"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
