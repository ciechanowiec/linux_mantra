#!/usr/bin/env python3
"""Lint an AsciiDoc document against the deterministic rules of the guideline.

The linter runs three engines and merges their findings into one stream:

  1. Vale (an external binary) for prose tokens and typography. Its config
     lives at the project root in `.vale.ini` + `.vale/styles/`. Vale is
     required: when the `vale` binary is not on PATH, the linter exits with an
     error rather than silently skipping the prose checks. Vale runs twice: on
     the document as-is, then (`run_vale_tables`) on the prose lifted out of
     `|===` table cells, because Vale's AsciiDoc parser never gives cell text a
     `sentence`/`paragraph` scope and so skips those rules inside tables -- the
     second pass makes a rule that applies to body prose apply to cell prose.
  2. The structural engine in this file for the markup, tree, and ASCII-diagram
     rules that Vale cannot see, because Vale lints rendered prose and loses the
     markup layer (heading depth, list nesting, anchor syntax, box-drawing).
  3. Asciidoctor (an external binary) as a render pass: the document is
     converted to temporary HTML and every WARNING-or-worse message (missing
     includes, malformed markup) is mapped onto the finding stream. The HTML
     is also checked for footnote macros and citation passthrough delimiters
     left literal in rendered prose.
     Asciidoctor does NOT validate internal cross-references, so the
     structural rule `xref-targets` covers that gap.

Only the mechanically-checkable slice of `README-guideline-writing.adoc` is enforced
here. Rules of prose judgement (nomenclature drift, false universals, "don't
invent facts") need a reader of the guideline, not a linter, and are out of
scope by design.

The source-citation rules add two external binaries, `pdftotext` (poppler)
and `tesseract`, required like vale and asciidoctor: `pdftotext` extracts the
text that the quote checks grep in PDF sources, and `tesseract` reads the OCR
text of image sources. An OCR miss warns instead of gating because OCR is
lossy.

Every structural check is an `error` that gates the run (non-zero exit). A check
that can't be made reliable enough to gate is left out rather than downgraded to
a non-gating hint. Vale findings keep the severity Vale assigns them.

To add a rule: write a function `(doc: Document) -> Iterator[(line, col, msg)]`
near the others in its banner section, then append a `Rule(...)` entry to the
`RULES` list with its id (the guideline anchor), its default severity, and the
function. Each rule's banner states the WHY and the guideline section it serves.

A project tunes the structural rules by editing the `RULES` list below: set a
rule's `enabled` to False to switch it off, change its `severity`, or add a new
`Rule(...)` entry.

Usage: python3 adoc_lint.py [--format text|json] <file.adoc> [<file.adoc> ...]
"""
import email
import email.policy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from dataclasses import dataclass, field
from html.parser import HTMLParser
from typing import Callable, Dict, Iterator, List, Optional, Set, Tuple

Finding = Tuple[int, int, str]  # (line, col, message) yielded by a rule
RuleFunc = Callable[["Document"], Iterator[Finding]]


# ============================================================================
# Source model -- a block-aware line scanner
# ============================================================================
#
# The one non-obvious capability the structural engine needs is to know which
# delimited block each line sits in. The guideline itself is full of
# `[source,asciidoc]----...----` blocks that SHOW markers as examples, so a
# naive scan for `^==` or `^..` would fire on every example. Verbatim blocks
# (listing `----`, literal `....`, comment `////`, passthrough `++++`) are
# tracked so structural rules skip their content -- and so the ASCII-diagram
# rules can do the opposite and run ONLY inside literal blocks.
#
# Section headings are valid only at the top level, never inside a delimited
# block, so a nesting counter for the non-verbatim delimited blocks (example
# `====`, sidebar `****`, quote `____`, open `--`, table `|===`) gates heading
# recording. Their prose content still lints as normal text.

VERBATIM_OPEN_RE = re.compile(r"^([-.+/])\1{3,}$")  # ---- .... ++++ ////
VERBATIM_BLOCK = {"-": "listing", ".": "literal", "/": "comment", "+": "pass"}
OTHER_DELIM_RE = re.compile(r"^(={4,}|\*{4,}|_{4,}|--|\|={3,})$")
HEADING_RE = re.compile(r"^(=+)\s+\S")


@dataclass
class Line:
    num: int          # 1-based
    text: str         # raw, no trailing newline
    block: str        # 'none' | 'listing' | 'literal' | 'comment' | 'pass'
    in_table: bool = False  # inside a |=== cell, where prose heuristics don't apply


@dataclass
class Document:
    path: str
    lines: List[Line]
    headings: List[Tuple[int, int]]  # (line_num, level) for level-1+ headings
    sources: "Optional[SourceAnalysis]" = None  # lazy, via source_analysis()


def scan(path: str) -> Document:
    with open(path, encoding="utf-8") as f:
        raw = f.read().splitlines()

    lines: List[Line] = []
    headings: List[Tuple[int, int]] = []
    verbatim = None       # the open verbatim block kind, or None
    verbatim_delim = ""   # the exact delimiter string that closes it
    other_stack: List[str] = []  # nesting of non-verbatim delimited blocks
    in_table = False

    for num, text in enumerate(raw, start=1):
        token = text.strip()

        if verbatim is not None:
            lines.append(Line(num, text, verbatim, in_table))
            if token == verbatim_delim:
                verbatim, verbatim_delim = None, ""
            continue

        vm = VERBATIM_OPEN_RE.match(token)
        if vm:
            verbatim = VERBATIM_BLOCK[token[0]]
            verbatim_delim = token
            lines.append(Line(num, text, verbatim, in_table))
            continue

        if token.startswith("//") and not token.startswith("////"):
            lines.append(Line(num, text, "comment", in_table))
            continue

        if OTHER_DELIM_RE.match(token):
            if other_stack and other_stack[-1] == token:
                other_stack.pop()
            else:
                other_stack.append(token)
            lines.append(Line(num, text, "none", in_table))
            if token.startswith("|="):
                in_table = not in_table
            continue

        if not other_stack:
            hm = HEADING_RE.match(text)
            if hm:
                headings.append((num, len(hm.group(1))))
        lines.append(Line(num, text, "none", in_table))

    return Document(path, lines, headings)


def _prose(doc: Document) -> Iterator[Line]:
    for line in doc.lines:
        if line.block == "none":
            yield line


# An inline code span (`...`) holds a technical literal, not live markup, so a
# macro shown as an example -- `image::x[]`, `<<_id>>` -- is illustrative, not a
# real defect. Mask span contents with spaces before the macro rules run; the
# replacement keeps the line length, so reported columns stay correct.
CODE_SPAN_RE = re.compile(r"`+[^`]*`+")
# A citation quote -- `"+...+"`, a quoted inline passthrough -- is source
# wording, not the author's markup, so the inline rules treat it like a code
# span and see only blanks of the same length.
QUOTED_PASS_RE = re.compile(r'"\+.*?\+"')


def _mask_code(text: str) -> str:
    masked = CODE_SPAN_RE.sub(lambda m: " " * len(m.group(0)), text)
    return QUOTED_PASS_RE.sub(lambda m: " " * len(m.group(0)), masked)


# ============================================================================
# Source citations -- parsed model
# ============================================================================
#
# Serves the source-citation rules (§claim-classes, §closed-source-list,
# §source-identity, §citation-scope, §quote-and-locator, §citation-footnotes):
# a document that derives statements from sources cites them in citation
# footnotes -- `footnote:id[<<bib-anchor>>, LOCATOR: "+QUOTE+"]`, several
# sources separated by `; `, an inferred claim prefixed `Inferred from: ` --
# resolved against a closed bibliography: the document's last section,
# marked by a `[[sources]]` anchor above its heading, holding one
# `. [[id,Label]]_Label_ - ...` ordered-list entry per source. The Label is
# the reference text every `<<id>>` renders. This section parses that
# apparatus once into a SourceAnalysis
# cached on the Document; the citation rules, the exemptions grafted onto
# older rules, the Vale post-filter, and the sibling `export_prepare.py` all
# consume the same parse instead of re-deriving spans with slightly different
# regexes.
#
# The parse reads RAW line text, not `_mask_code` output: the verbatim quote
# and the archived path live inside backtick spans, which masking blanks.
# Footnote OPENINGS are located on masked text, though, so an inline-code
# example of the syntax never counts as a real citation -- the macro body is
# then sliced from the raw text at the same offsets, which masking preserves.

BIB_MARKER = "[[sources]]"
SF_STYLE_LINE = "[horizontal.source-fields]"
BIB_ENTRY_RE = re.compile(r"^\s*\.\s+\[\[([^\[\],]+),([^\]]+)\]\](.*)$")
BIB_FIELD_RE = re.compile(r"^([A-Z][A-Za-z0-9 -]*?)::\s+(.*)$")
TRIPLE_ANCHOR_RE = re.compile(r"\[\[\[([^\]]+)\]\]\]")
KEBAB_ID_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")

# The metadata schema of a bibliography entry. The field names below appear
# identically in three places -- the guideline's tables (§source-identity),
# the `Key:: value` lines of the markup (§bibliography-markup), and these
# dictionaries -- so there is exactly one vocabulary to maintain. Each field
# carries a shape name resolved through SHAPES; "text" is presence-only.
SHAPES = {
    "text": None,
    "date": (re.compile(r"^\d{4}-\d{2}-\d{2}$"),
             "an ISO date YYYY-MM-DD"),
    "flexdate": (re.compile(r"^\d{4}(?:-\d{2}(?:-\d{2})?)?$"),
                 "an ISO date YYYY, YYYY-MM, or YYYY-MM-DD"),
    "year": (re.compile(r"^\d{4}$"), "a year YYYY"),
    "path": (re.compile(r"^`((?:[^`\s]*/)?\.docs/sources/[^`]+)`$"),
             "a backticked `.docs/sources/...` path"),
    "digest": (re.compile(r"^`\+([0-9a-fA-F]{64})\+`$"),
               "a monospaced literal `+<64 hex>+`"),
    "url": (re.compile(r"^https?://\S+$"), "an http or https URL"),
    "status": (re.compile(r"^(?:draft|final)\b"),
               "draft or final, with optional elaboration"),
    "email": (re.compile(r"^(?:[^<>]+<[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+>"
                         r"|[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+)$"),
              "an email address, optionally prefixed with a name as "
              "'Name <address>'"),
    "datetime": (re.compile(r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?"
                            r"(?:[ ]?(?:Z|UTC|[+-]\d{2}:?\d{2}"
                            r"|[A-Za-z_]+/[A-Za-z_]+))?$"),
                 "an ISO date and exact time YYYY-MM-DD HH:MM, timezone "
                 "optional"),
}

# type -> ([required (key, shape)...], [optional (key, shape)...]); the tuple
# order is also the serialization order the entries follow. A field is
# required only when it is constitutional for the type -- every artifact of
# the type has it -- so most descriptive fields are optional.
TYPE_SCHEMA = {
    "Contract": ([("Parties", "text")],
                 [("Concluded on", "date"), ("Governing law", "text")]),
    "Legal source": ([("Issuing body", "text"), ("Identifier", "text")],
                     [("Date", "flexdate")]),
    "Official record": ([("Register", "text")],
                        [("Entry number", "text")]),
    "Financial record": ([("Issuer", "text")],
                         [("Kind", "text"), ("Number", "text"),
                          ("Date", "date"), ("Amount", "text")]),
    "Correspondence": ([("Participants", "text")],
                       [("Platform", "text"), ("Sender", "text"),
                        ("Addressee", "text"), ("Sent on", "date"),
                        ("Time range", "text"), ("Subject", "text")]),
    "Email": ([("Sender", "email"), ("Sent on", "datetime")],
              [("Recipients", "text"),
               ("Subject", "text"), ("Time range", "text")]),
    "Minutes": ([("Held on", "date")],
                [("Participants", "text"), ("Recorder", "text")]),
    "Report": ([], [("Author", "text"), ("Date", "flexdate"),
                    ("Period covered", "text")]),
    "Specification": ([("System", "text")],
                      [("Author", "text"), ("Date", "flexdate"),
                       ("Version", "text")]),
    "Standard": ([("Identifier", "text")],
                 [("Issuing body", "text"), ("Year", "year"),
                  ("Version", "text")]),
    "Publication": ([("Authors", "text")],
                    [("Year", "year"), ("Publisher", "text"), ("Edition", "text"),
                     ("ISBN", "text"), ("DOI", "text")]),
    "Web page": ([], [("Site", "text"), ("Published on", "flexdate")]),
    "Presentation": ([], [("Author", "text"), ("Date", "flexdate"),
                          ("Slides", "text")]),
    "Workbook": ([], [("Owner", "text"), ("Date", "flexdate"),
                      ("Sheets", "text")]),
    "Ticket": ([("Tracker", "text"), ("Ticket number", "text")],
               [("Ticket state", "text")]),
    "Repository": ([("Host and path", "text")],
                   [("Commit", "text"), ("Branch", "text")]),
    "System output": ([("System", "text")],
                      [("Query", "text"), ("Captured on", "date")]),
    "Image": ([("Depicts", "text")],
              [("Captured as", "text"), ("Captured on", "date"),
               ("Place", "text")]),
    "Recording": ([("Medium", "text")],
                  [("Date", "date"), ("Participants", "text"),
                   ("Duration", "text")]),
    "Other": ([("Description", "text")],
              [("Date", "flexdate"), ("Version", "text")]),
}

STATUS_KEYS = [("Status", "status")]

# Types whose entries always state their status: the requirement belongs to
# the status dimension (§source-status), not to the type's own field set.
STATUS_REQUIRED_TYPES = {"Contract"}

CLASS_SCHEMA = {
    "archived-file": ([("Archived as", "path"),
                       ("SHA-256", "digest")], []),
    "web": ([("URL", "url"), ("Accessed", "date")], [("Access", "text")]),
    "request": ([("Request of", "date"), ("By", "text")], []),
    "unarchived": ([("Not archived", "text")], []),
}

# Any of these keys pins the entry to its reachability class; mixing keys of
# two classes is a schema error.
CLASS_SIGNATURE = {
    key: cls
    for cls, (required, optional) in CLASS_SCHEMA.items()
    for key, _shape in required + optional
}
FOOTNOTE_OPEN_RE = re.compile(r"footnote:([\w-]*)\[")
FOOTNOTE_REUSE_RE = re.compile(r"footnote:([\w-]+)\[\]")
CITE_INFER_PREFIX = "Inferred from: "
CITE_SEP = "; "
# One cited source: `<<anchor>>, locator: "+quote+"`. The locator is optional
# (a requester's brief has no pages, so `<<anchor>>: "+quote+"`); the quote is
# optional for a source whose support is visual (an image) -- then the
# locator alone, colon-free, carries the reference. Locators never contain
# backticks or semicolons: `;` is the source separator.
CITE_ITEM_QUOTE_RE = re.compile(
    r"<<([A-Za-z0-9_-]+)>>(?:,\s+([^`;]*?))?:\s+\"\+(.+?)\+\"")
CITE_ITEM_NOQUOTE_RE = re.compile(
    r"<<([A-Za-z0-9_-]+)>>,\s+([^`;:]+?)(?=; |$)")


@dataclass
class BibEntry:
    id: str            # kebab id from the [[id,Label]] anchor
    label: str         # reference label: what references render
    line: int          # 1-based source line of the item line
    item_text: str     # item text after the anchor; must be '_Label_'
    fields: Dict[str, Tuple[str, int]] = field(default_factory=dict)
    style_line: bool = False  # the [horizontal.source-fields] attribute seen
    dup_keys: List[Tuple[str, int]] = field(default_factory=list)
    cls: str = ""      # 'archived-file'|'web'|'request'|'unarchived'|'none'|'ambiguous'
    path: str = ""     # archived-file: recorded doc-relative path
    sha256: str = ""   # archived-file: recorded digest, lowercased


@dataclass
class SourceRef:
    anchor: str
    locator: str
    quote: str         # verbatim, with '\]' unescaped back to ']'
    col: int           # 1-based column of '<<' in its line


@dataclass
class CitationFootnote:
    id: str            # '' for an anonymous citation footnote
    line: int
    start_col: int     # 1-based column of 'footnote:'
    end_col: int       # 1-based column just past the closing ']'
    body: str          # raw body, escapes intact; '' for a reuse
    is_inference: bool
    is_reuse: bool
    sources: List[SourceRef]
    parse_error: Optional[Tuple[int, str]] = None  # (1-based col, detail)


@dataclass
class SourceAnalysis:
    bib_attr_line: int          # line of the '[[sources]]' marker, 0 when absent
    bib_heading_line: int       # line of the section heading under it, 0 when absent
    bib_end_line: int           # last line of the bibliography section
    entries: List[BibEntry]
    bib_ids: Set[str]
    citations: List[CitationFootnote]   # definitions AND reuses, document order
    citation_ids: Set[str]              # ids of citation definitions
    stray_triple_anchors: List[Tuple[int, int, str]]  # [[[x]]] outside the bib
    bad_bib_lines: List[Tuple[int, str]]  # bibliography lines that fit no rule
    # lazy caches filled by the rule helpers below:
    mode: str = ""                      # '' | 'pinned' | 'draft' | 'nogit'
    pinned_findings: Optional[List[Finding]] = None
    quote_results: Optional[List[Tuple[Finding, str]]] = None
    quote_stats: Optional[Dict[str, int]] = None  # checked/verified, ocr_*
    sha_cache: Dict[str, str] = field(default_factory=dict)


def _macro_end(text: str, start: int) -> int:
    """Index of the ']' closing an inline-macro body that starts at `start`,
    or -1. Mirrors the walker of rule_footnote_bare_bracket: '\\' escapes the
    next character, and an unescaped '[' directly after a non-space begins a
    nested inline macro that is skipped to its matching ']'."""
    i = start
    while i < len(text):
        char = text[i]
        if char == "\\":
            i += 2
            continue
        if char == "]":
            return i
        if char == "[" and i > 0 and not text[i - 1].isspace():
            depth = 1
            i += 1
            while i < len(text) and depth > 0:
                depth += (text[i] == "[") - (text[i] == "]")
                i += 1
            continue
        i += 1
    return -1


def _classify_entry(entry: BibEntry) -> None:
    """Fill entry.cls (and path/sha256) from the class-signature keys. One
    class's keys pin the entry to that reachability class; keys of two
    classes are contradictory and land in 'ambiguous', no key in 'none'."""
    classes = {CLASS_SIGNATURE[key] for key in entry.fields
               if key in CLASS_SIGNATURE}
    if not classes:
        entry.cls = "none"
        return
    if len(classes) > 1:
        entry.cls = "ambiguous"
        return
    entry.cls = classes.pop()
    if entry.cls == "archived-file":
        path_value = entry.fields.get("Archived as", ("", 0))[0]
        sha_value = entry.fields.get("SHA-256", ("", 0))[0]
        path_m = SHAPES["path"][0].match(path_value)
        sha_m = SHAPES["digest"][0].match(sha_value)
        entry.path = path_m.group(1) if path_m else ""
        entry.sha256 = sha_m.group(1).lower() if sha_m else ""


def _parse_citation_items(cf: CitationFootnote, rest: str,
                          base_col: int) -> None:
    """Parse the source list of a citation footnote body. `rest` is the body
    with any 'Inferred from: ' prefix removed; `base_col` is its 0-based
    offset in the source line, so failure columns land exactly."""
    pos = 0
    while True:
        m = CITE_ITEM_QUOTE_RE.match(rest, pos)
        if m:
            quote = m.group(3).replace("\\]", "]")
            cf.sources.append(SourceRef(
                m.group(1), (m.group(2) or "").strip(), quote,
                base_col + m.start() + 1))
            pos = m.end()
        else:
            m = CITE_ITEM_NOQUOTE_RE.match(rest, pos)
            if m:
                cf.sources.append(SourceRef(
                    m.group(1), m.group(2).strip(), "",
                    base_col + m.start() + 1))
                pos = m.end()
            else:
                cf.parse_error = (
                    base_col + pos + 1,
                    f"unparseable source item at {rest[pos:pos + 40]!r}")
                return
        if pos == len(rest):
            return
        if rest.startswith(CITE_SEP, pos):
            pos += len(CITE_SEP)
            continue
        cf.parse_error = (base_col + pos + 1,
                          "expected '; ' before the next source or the end "
                          "of the footnote")
        return


def _build_source_analysis(doc: Document) -> SourceAnalysis:
    n_lines = len(doc.lines)

    bib_attr = 0
    for line in _prose(doc):
        if line.text.strip() == BIB_MARKER:
            bib_attr = line.num
            break
    bib_heading = 0
    bib_end = 0
    if bib_attr:
        for num, _level in doc.headings:
            if num > bib_attr:
                bib_heading = num
                break
        following = [num for num, _ in doc.headings
                     if bib_heading and num > bib_heading]
        bib_end = (following[0] - 1) if following else n_lines

    entries: List[BibEntry] = []
    stray: List[Tuple[int, int, str]] = []
    bad_bib_lines: List[Tuple[int, str]] = []
    current: Optional[BibEntry] = None
    for line in _prose(doc):
        in_bib = bib_attr and bib_attr <= line.num <= bib_end
        if in_bib:
            text = line.text
            stripped = text.strip()
            em = BIB_ENTRY_RE.match(text)
            if em:
                current = BibEntry(em.group(1).strip(),
                                   em.group(2).strip(), line.num,
                                   em.group(3).strip())
                entries.append(current)
                continue
            if not stripped or stripped == BIB_MARKER \
                    or line.num == bib_heading:
                continue
            if stripped == SF_STYLE_LINE and current:
                current.style_line = True
                continue
            fm = BIB_FIELD_RE.match(text)
            if fm and current:
                key = fm.group(1)
                if key in current.fields:
                    current.dup_keys.append((key, line.num))
                else:
                    current.fields[key] = (fm.group(2).strip(), line.num)
                continue
            if line.num > bib_heading:
                bad_bib_lines.append((line.num, stripped))
            continue
        for tm in TRIPLE_ANCHOR_RE.finditer(_mask_code(line.text)):
            stray.append((line.num, tm.start() + 1, tm.group(1)))
    for entry in entries:
        _classify_entry(entry)

    citations: List[CitationFootnote] = []
    citation_ids: Set[str] = set()
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for om in FOOTNOTE_OPEN_RE.finditer(masked):
            end = _macro_end(line.text, om.end())
            if end == -1:
                continue  # unterminated macro; other rules report it
            body = line.text[om.end():end]
            if not body:
                continue  # a reuse; collected in the second pass
            is_inference = body.startswith(CITE_INFER_PREFIX)
            rest = body[len(CITE_INFER_PREFIX):] if is_inference else body
            if not rest.startswith("<<"):
                continue  # an ordinary footnote, not a citation
            cf = CitationFootnote(
                om.group(1), line.num, om.start() + 1, end + 2, body,
                is_inference, False, [])
            if rest.endswith("."):
                rest = rest[:-1]  # the terminal period of §footnote-punctuation
            offset = om.end() + (len(CITE_INFER_PREFIX) if is_inference else 0)
            _parse_citation_items(cf, rest, offset)
            citations.append(cf)
            if cf.id:
                citation_ids.add(cf.id)
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for rm in FOOTNOTE_REUSE_RE.finditer(masked):
            if rm.group(1) in citation_ids:
                citations.append(CitationFootnote(
                    rm.group(1), line.num, rm.start() + 1, rm.end() + 1,
                    "", False, True, []))

    return SourceAnalysis(bib_attr, bib_heading, bib_end, entries,
                          {e.id for e in entries}, citations, citation_ids,
                          stray, bad_bib_lines)


def source_analysis(doc: Document) -> SourceAnalysis:
    if doc.sources is None:
        doc.sources = _build_source_analysis(doc)
    return doc.sources


def _in_bib(ana: SourceAnalysis, line_num: int) -> bool:
    return bool(ana.bib_attr_line
                and ana.bib_attr_line <= line_num <= ana.bib_end_line)


# ============================================================================
# Heading tree -- depth and lone subsections
# ============================================================================
#
# Serves section-nesting (README-guideline-writing §section-nesting): a heading nests
# at most five levels below the title, so `==`..`======` are the only section
# headings and `=======` is too deep. A section also has zero subsections or
# two or more -- a lone subsection means its content belongs in the parent's
# prose, or a sibling is missing.

def rule_heading_depth(doc: Document) -> Iterator[Finding]:
    for line_num, level in doc.headings:
        if level > 6:
            yield (line_num, 1,
                   f"Heading is {level - 1} levels deep, exceeding the guideline "
                   f"maximum of 5 (§section-nesting)")


def rule_lone_subsection(doc: Document) -> Iterator[Finding]:
    sections = [(ln, lv) for ln, lv in doc.headings if lv >= 2]
    for i, (_, level) in enumerate(sections):
        children = 0
        first_child = None
        j = i + 1
        while j < len(sections) and sections[j][1] > level:
            if sections[j][1] == level + 1:
                children += 1
                if first_child is None:
                    first_child = sections[j][0]
            j += 1
        if children == 1 and first_child is not None:
            yield (first_child, 1,
                   "Lone subsection where a section needs zero subsections or "
                   "two or more (§section-nesting)")


# ============================================================================
# List markers -- numbering depth
# ============================================================================
#
# Serves numbering-depth (§numbering-depth): the ordered ladder is `.` `..`
# `...` `....` (four dot levels) and the unordered ladder is `*` `**` (two
# star levels). Nothing nests deeper. A block title (`.Title`, no space) and a
# bold span (`*word*`, no space) are excluded because a list marker is always
# followed by whitespace.

ORDERED_MARKER_RE = re.compile(r"^(\.+)\s+\S")
UNORDERED_MARKER_RE = re.compile(r"^(\*+)\s+\S")


def rule_numbering_depth(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        om = ORDERED_MARKER_RE.match(line.text)
        if om and len(om.group(1)) > 4:
            yield (line.num, 1,
                   f"Ordered list nested {len(om.group(1))} levels, beyond the "
                   f"dot ladder limit of `....` (§numbering-depth)")
            continue
        um = UNORDERED_MARKER_RE.match(line.text)
        if um and len(um.group(1)) > 2:
            yield (line.num, 1,
                   f"Unordered list nested {len(um.group(1))} levels, beyond the "
                   f"star ladder limit of `**` (§numbering-depth)")


# ============================================================================
# List structure -- continuations and starts that render as literal text
# ============================================================================
#
# Render-integrity checks for AsciiDoc list markup that fails silently.
# Asciidoctor reports none of these cases (verified empirically: conversion
# exits 0 with no warning), so literal markers can reach the reader as body
# text. The rules below are the deterministic, precisely-located backstop the
# render pass can't give:
#
#   * orphan-continuation (Mode A): a list continuation is a lone `+` line that
#     attaches the block below it to the list item above it. With no list open
#     above it, the `+` has nothing to attach to and renders as a literal `+`.
#     Scanning upward past blank lines, continuation paragraphs, and already-
#     attached verbatim blocks, this rule finds a heading, a block delimiter, or
#     the document start before any list marker.
#
#   * glued-list-item (Mode B): a list's FIRST item must be separated from the
#     paragraph above it by a blank line (or sit under a heading, delimiter,
#     block title, or attribute line). An item glued directly onto a preceding
#     paragraph opens no clean list, and every `+` continuation under it renders
#     literally. This rule flags such a first item -- but skips an item whose
#     preceding line already belongs to an open list (a wrapped item line), so a
#     legitimate multi-line list is never touched.
#
#   * continuation-content (Mode C): a continuation paragraph can be followed
#     by a deeper list only when another `+` line attaches that list to the same
#     parent. Without the second `+`, Asciidoctor joins the deeper markers to the
#     continuation paragraph as literal text.
#
# All run in prose (`none`) blocks only, so markers shown inside a `[source]`
# example, or a `+` standing in a table cell (a legal cell continuation), are
# left alone. Each flags only the single line that breaks the structure -- the
# stray `+`, glued first item, or detached deeper item -- since fixing it repairs
# the cascade below.

LABELED_MARKER_RE = re.compile(r"^\s*\S.*?::(\s|$)")
BLOCK_TITLE_RE = re.compile(r"^\.\S")


def _opens_list(line: Line) -> bool:
    return bool(ORDERED_MARKER_RE.match(line.text)
                or UNORDERED_MARKER_RE.match(line.text)
                or LABELED_MARKER_RE.match(line.text))


def _lines_above(doc: Document, start_idx: int) -> Iterator[Tuple[Line, str]]:
    """Yield (line, stripped-text) for the source lines above `start_idx`,
    nearest first, stepping over the interiors AND delimiters of blocks so an
    attached block between a list item and its `+` continuation is skipped
    rather than mistaken for a scope boundary. Verbatim blocks (listing,
    literal, comment, pass) are already marked with a non-`none` block by the
    scanner and skipped here; the other delimited blocks (table `|===`, example
    `====`, sidebar `****`, quote `____`, open `--`) are stepped over with a
    token-matched depth counter, since a list item's attached content routinely
    holds a table or nested block."""
    depth: List[str] = []
    for j in range(start_idx, -1, -1):
        prev = doc.lines[j]
        if prev.block != "none":
            continue  # inside a verbatim block (interior or its own delimiters)
        token = prev.text.strip()
        if OTHER_DELIM_RE.match(token):
            if depth and depth[-1] == token:
                depth.pop()   # reached this block's opening delimiter
            else:
                depth.append(token)  # entered from a closing delimiter, going up
            continue
        if depth:
            continue  # inside an attached delimited block; step over its content
        yield prev, token


def rule_orphan_continuation(doc: Document) -> Iterator[Finding]:
    for i, line in enumerate(doc.lines):
        if line.block != "none" or line.in_table or line.text.strip() != "+":
            continue
        list_open = False
        for prev, token in _lines_above(doc, i - 1):
            if token == "" or token == "+":
                continue  # a blank line, or another link in the same chain
            if HEADING_RE.match(prev.text):
                break  # list scope boundary reached with no item above it
            if _opens_list(prev):
                list_open = True
                break
            # a plain paragraph, block title, or attribute line: keep scanning up
        if not list_open:
            yield (line.num, 1,
                   "List continuation `+` with no list item open above it, so "
                   "it renders as a literal `+` instead of attaching a block")


def _marker_in_run_above(doc: Document, idx: int) -> bool:
    """True if the line at `idx` is text belonging to an already-open list item.
    Scanning up the contiguous non-blank run it sits in, that is signalled by a
    list marker, or by a `+` continuation -- which only exists inside an open
    list, so it attaches its run to the list even across the blank line above."""
    for prev, token in _lines_above(doc, idx):
        if token == "+":
            return True  # a continuation marker: the run is attached to a list
        if token == "":
            return False  # a blank line ends the run with no marker found
        if HEADING_RE.match(prev.text):
            return False
        if _opens_list(prev):
            return True
    return False


def rule_glued_list_item(doc: Document) -> Iterator[Finding]:
    for i, line in enumerate(doc.lines):
        if line.block != "none" or line.in_table or i == 0:
            continue
        if not _opens_list(line):
            continue
        prev = doc.lines[i - 1]
        if prev.block != "none":
            continue
        token = prev.text.strip()
        # A blank line, or any non-prose line that legally opens a list below it,
        # means the item starts cleanly.
        if (token in ("", "+") or HEADING_RE.match(prev.text)
                or OTHER_DELIM_RE.match(token) or _opens_list(prev)
                or BLOCK_TITLE_RE.match(token) or token.startswith(("[", "//"))):
            continue
        # `prev` is a prose line. If it already belongs to an open list (a
        # wrapped item line), this marker is a sibling item, not a glued start.
        if _marker_in_run_above(doc, i - 1):
            continue
        yield (line.num, 1,
               "List item is glued to the paragraph above it with no blank line "
               "between them, so the list opens no continuations and any `+` "
               "under it renders as literal text")


def _numbered_marker_rank(line: Line) -> Optional[int]:
    """Return the guideline's six-level list rank, or None for non-items."""
    ordered = ORDERED_MARKER_RE.match(line.text)
    if ordered:
        return len(ordered.group(1))
    unordered = UNORDERED_MARKER_RE.match(line.text)
    if unordered:
        return 4 + len(unordered.group(1))
    return None


def rule_continuation_content(doc: Document) -> Iterator[Finding]:
    """Reject a deeper list detached from its parent continuation paragraph.

    In this invalid shape::

        . Parent
        +
        Continuation paragraph.
        .. Child

    the child marker renders literally. A `+` immediately before `.. Child`
    closes the paragraph block and attaches the deeper list to `Parent`.
    """
    for i, line in enumerate(doc.lines):
        if line.block != "none" or line.in_table:
            continue
        child_rank = _numbered_marker_rank(line)
        if child_rank is None:
            continue

        # A `+` immediately before the deeper item is the required attachment.
        j = i - 1
        while j >= 0 and doc.lines[j].text.strip() == "":
            j -= 1
        if j < 0 or doc.lines[j].text.strip() == "+":
            continue
        if doc.lines[j].block != "none" or doc.lines[j].in_table:
            continue

        # Walk over the continuation paragraph to the `+` that opened it.
        continuation_plus = None
        k = j
        while k >= 0:
            candidate = doc.lines[k]
            if candidate.block != "none" or candidate.in_table:
                break
            token = candidate.text.strip()
            if token == "+":
                continuation_plus = k
                break
            if (token == "" or HEADING_RE.match(candidate.text)
                    or _opens_list(candidate) or OTHER_DELIM_RE.match(token)
                    or BLOCK_TITLE_RE.match(token) or token.startswith("[")):
                break
            k -= 1
        if continuation_plus is None:
            continue

        # Locate the numbered paragraph to which that continuation belongs.
        parent_rank = None
        for parent, token in _lines_above(doc, continuation_plus - 1):
            if token in ("", "+"):
                continue
            parent_rank = _numbered_marker_rank(parent)
            if parent_rank is not None or HEADING_RE.match(parent.text):
                break
        if parent_rank is None or child_rank <= parent_rank:
            continue  # a same-level sibling ends a continuation without `+`

        yield (line.num, 1,
               "Deeper list follows a continuation paragraph without the "
               "required `+` attachment, so its marker renders as literal text "
               "(§continuation-content)")


# ============================================================================
# List structure -- a list has two or more items
# ============================================================================
#
# Serves lists-for-enumerable-content (§lists-for-enumerable-content): a list
# enumerates parallel items, so a list of one item is a bulleted paragraph that
# renders as an orphaned "A." (or "1.", "*") with no sibling. This is the list
# analogue of lone-subsection, which forbids a lone *subsection*; the same "zero,
# or two or more" rule is enforced here for list items at EVERY nesting level of
# BOTH ladders (`.` `..` and `*` `**`).
#
# Lists are grouped with a marker stack. An item whose marker isn't open pushes a
# new (nested) list; an item at an already-open marker closes the deeper levels
# above it and increments its own count. A heading or a fresh, unattached prose
# paragraph closes every open list. Verbatim blocks, table cells, block
# delimiters, continuations (`+`), attribute lines, block titles, comments, and
# wrapped item text are attached or inert and never close a list, so an item
# carrying an attached table or diagram keeps its siblings. Each list is checked
# as it closes: a count of one flags the item's line.

def _ends_list(line: Line, idx: int, doc: Document) -> bool:
    if line.block != "none" or line.in_table:
        return False
    if HEADING_RE.match(line.text):
        return True
    token = line.text.strip()
    if token in ("", "+"):
        return False
    if (_opens_list(line) or OTHER_DELIM_RE.match(token)
            or BLOCK_TITLE_RE.match(token) or token.startswith(("[", "//"))):
        return False
    # A plain prose line closes the list only when it starts a fresh paragraph,
    # not when it is the wrapped or `+`-attached continuation of the item above.
    return not _marker_in_run_above(doc, idx)


def rule_single_item_list(doc: Document) -> Iterator[Finding]:
    findings: List[Finding] = []
    stack: List[List] = []  # each entry: [marker, count, first_line_num]
    ana = source_analysis(doc)

    def close_top() -> None:
        marker, count, line_num = stack.pop()
        # The bibliography is a ledger, not a prose enumeration: a document
        # resting on one source legitimately lists one entry.
        if count == 1 and not _in_bib(ana, line_num):
            findings.append((line_num, 1,
                f"Single-item list: the `{marker}` list has one item where a "
                f"list needs two or more, so write the item as prose "
                f"(§lists-for-enumerable-content)"))

    for idx, line in enumerate(doc.lines):
        if line.block != "none" or line.in_table:
            continue
        m = (ORDERED_MARKER_RE.match(line.text)
             or UNORDERED_MARKER_RE.match(line.text))
        if m:
            marker = m.group(1)
            if any(entry[0] == marker for entry in stack):
                while stack[-1][0] != marker:
                    close_top()
                stack[-1][1] += 1
            else:
                stack.append([marker, 1, line.num])
        elif _ends_list(line, idx, doc):
            while stack:
                close_top()

    while stack:
        close_top()
    yield from findings


# ============================================================================
# Images -- alt text
# ============================================================================
#
# Serves alt-text-and-captions (§alt-text-and-captions): every figure carries
# a textual equivalent. The alt text is the first positional attribute of the
# image macro, so an empty `[]` or a macro that opens with `,` (jumping
# straight to a named attribute) has no alt text.

IMAGE_RE = re.compile(r"image:{1,2}[^\[\]\s]+\[([^\]]*)\]")


def rule_image_alt_text(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for m in IMAGE_RE.finditer(_mask_code(line.text)):
            first_positional = m.group(1).split(",", 1)[0].strip()
            if not first_positional:
                yield (line.num, m.start() + 1,
                       "Image has no alt text stating what the figure shows "
                       "(§alt-text-and-captions)")


# ============================================================================
# Links -- descriptive text
# ============================================================================
#
# Serves link-text-carries-the-claim (§link-text-carries-the-claim): the link
# text is the phrase the source substantiates, so the sentence keeps its
# meaning when the markup is stripped. `here`, `this page`, and the like carry
# no information about the target. The `xref:` macro is excluded: its
# empty-bracket form is correct and inherits the target's title.

LINK_RE = re.compile(r"(?:link:[^\[\]\s]+|https?://[^\[\]\s]+)\[([^\]]*)\]")
NONDESCRIPTIVE = {
    "here", "this", "this page", "this link", "click here", "link", "read more",
    "more", "see here", "this document",
}


BARE_URL_RE = re.compile(r"https?://[^\s\[\]]+")


def rule_link_text(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for m in LINK_RE.finditer(masked):
            # Masking keeps offsets, so the raw slice recovers link text
            # whose content is itself a code span.
            raw_text = line.text[m.start(1):m.end(1)]
            text = raw_text.rstrip("^").strip()
            if text.lower() in NONDESCRIPTIVE:
                yield (line.num, m.start() + 1,
                       f"Non-descriptive link text {raw_text!r} that should "
                       f"wrap the phrase the source substantiates "
                       f"(§link-text-carries-the-claim)")
            if m.group(0).startswith("http"):
                if not text:
                    yield (line.num, m.start() + 1,
                           "External link with empty text renders the bare "
                           "URL; wrap the phrase the source substantiates "
                           "(§link-text-carries-the-claim)")
                elif not raw_text.endswith("^"):
                    yield (line.num, m.start() + 1,
                           "External link text doesn't end with '^', which "
                           "opens the target in a new tab "
                           "(§link-text-carries-the-claim)")
        if _in_bib(ana, line.num) or line.text.lstrip().startswith(":"):
            continue
        for m in BARE_URL_RE.finditer(LINK_RE.sub(" ", masked)):
            yield (line.num, m.start() + 1,
                   "Bare URL in prose carries no information about the "
                   "target; wrap the phrase the source substantiates "
                   "(§link-text-carries-the-claim)")


# ============================================================================
# Anchors -- explicit ids, kebab-case
# ============================================================================
#
# Serves explicit-anchors (§explicit-anchors): a cross-reference targets an
# explicit anchor, never an auto-generated id. An auto-generated id starts
# with `_` (Asciidoctor derives it from the heading text), so a reference to
# `<<_foo>>` or `xref:_foo` breaks the moment the heading is retitled. An
# explicit anchor id is lowercase kebab-case; uppercase, whitespace, or `_`
# in an id is a defect.

AUTO_ANCHOR_RE = re.compile(r"(?:<<|xref:#?)_[\w-]+")
# The lookarounds keep a bibliography anchor `[[[id]]]` from half-matching as
# a block anchor with a garbage leading-bracket id; triple anchors are owned
# by the source-citation analysis above.
BLOCK_ANCHOR_RE = re.compile(r"(?<!\[)\[\[(?!\[)([^\],]+)")
INLINE_ANCHOR_RE = re.compile(r"\[#([A-Za-z0-9_-]+)")


def rule_auto_anchor(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for m in AUTO_ANCHOR_RE.finditer(_mask_code(line.text)):
            yield (line.num, m.start() + 1,
                   "Reference to an auto-generated id instead of an explicit "
                   "anchor (§explicit-anchors)")


def rule_anchor_format(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for rx in (BLOCK_ANCHOR_RE, INLINE_ANCHOR_RE):
            for m in rx.finditer(masked):
                anchor = m.group(1)
                if anchor != anchor.lower() or " " in anchor or "_" in anchor:
                    yield (line.num, m.start() + 1,
                           f"anchor id {anchor!r} should be lowercase "
                           f"kebab-case (§explicit-anchors)")


# Serves explicit-anchors (§explicit-anchors) from the other side: a reference
# is only as good as its target. Asciidoctor's render pass does not validate
# internal cross-references (verified empirically: an `xref` to a missing id
# converts silently), so a retitled or deleted anchor leaves dangling links
# that nothing catches. This rule collects every explicit anchor id and flags
# any same-document reference whose target isn't among them. References to
# `_`-prefixed ids are skipped here because `rule_auto_anchor` already flags
# them. External-file references (`xref:other.adoc#...`) don't match the
# same-document patterns and are out of scope.

XREF_TARGET_RE = re.compile(r"xref:#([A-Za-z0-9_-]+)")
ANGLE_REF_RE = re.compile(r"<<([A-Za-z0-9_-]+)")


def rule_xref_targets(doc: Document) -> Iterator[Finding]:
    anchors = set()
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for m in BLOCK_ANCHOR_RE.finditer(masked):
            anchors.add(m.group(1).strip())
        for m in INLINE_ANCHOR_RE.finditer(masked):
            anchors.add(m.group(1))
    anchors |= source_analysis(doc).bib_ids  # [[[id]]] bibliography anchors
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for rx in (XREF_TARGET_RE, ANGLE_REF_RE):
            for m in rx.finditer(masked):
                target = m.group(1)
                if target.startswith("_") or target in anchors:
                    continue
                yield (line.num, m.start() + 1,
                       f"Cross-reference targets anchor {target!r}, which "
                       f"doesn't exist in the document (§explicit-anchors)")


# Serves no-section-heading-self-references
# (§no-section-heading-self-references): a reference to the current section's
# own heading adds link styling without navigation and suggests another
# destination. References to terms and other anchors defined inside the same
# section remain valid. "Current section" means the nearest preceding heading.

STANDALONE_BLOCK_ANCHOR_RE = re.compile(
    r"^\s*(?:\[\[(?!\[)[^\]]+\]\]|\[#(?:[A-Za-z0-9_-]+)\])\s*$")


def rule_no_section_heading_self_references(
        doc: Document) -> Iterator[Finding]:
    heading_lines = {line_num for line_num, _level in doc.headings}
    section_for_line: Dict[int, Optional[int]] = {}
    current_section: Optional[int] = None
    for line in doc.lines:
        if line.num in heading_lines:
            current_section = line.num
        section_for_line[line.num] = current_section

    next_content_line: Dict[int, Optional[int]] = {}
    next_num: Optional[int] = None
    for line in reversed(doc.lines):
        next_content_line[line.num] = next_num
        if line.block == "none" and line.text.strip():
            next_num = line.num

    section_anchors: Dict[int, Set[str]] = {}
    for line in _prose(doc):
        masked = _mask_code(line.text)
        if not STANDALONE_BLOCK_ANCHOR_RE.match(masked):
            continue
        following = next_content_line[line.num]
        if following not in heading_lines:
            continue
        for rx in (BLOCK_ANCHOR_RE, INLINE_ANCHOR_RE):
            for match in rx.finditer(masked):
                section_anchors.setdefault(following, set()).add(
                    match.group(1).strip())

    for line in _prose(doc):
        owner = section_for_line[line.num]
        if owner is None:
            continue
        masked = _mask_code(line.text)
        for rx in (XREF_TARGET_RE, ANGLE_REF_RE):
            for match in rx.finditer(masked):
                target = match.group(1)
                if target not in section_anchors.get(owner, set()):
                    continue
                yield (
                    line.num,
                    match.start() + 1,
                    f"Cross-reference to {target!r} targets the heading of "
                    f"the current section; write the section name as plain "
                    f"text (§no-section-heading-self-references)",
                )


# ============================================================================
# Footnote text -- no bare bracket
# ============================================================================
#
# Asciidoctor ends a footnote's text at the first `]` that doesn't close a nested
# inline macro, so a bare bracket inside the text -- `[sic]`, `[1]` -- silently
# truncates the footnote and spills the remainder onto the page. Its render pass
# does NOT warn (verified empirically: converts with exit 0, and the footnote just
# ends early). A macro's own `[` always follows its target (`xref:#id[`), never
# whitespace, so a whitespace-preceded `[` inside a footnote is that defect. Write
# the bracket as `{startsb}` and `{endsb}`, which render literally.

def rule_footnote_bare_bracket(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        text: str = line.text
        for opening in re.finditer(r"footnote:[\w-]*\[", text):
            i: int = opening.end()
            while i < len(text):
                char: str = text[i]
                if char == "\\":
                    i += 2
                    continue
                if char == "]":
                    break  # the footnote closes here
                if char == "[":
                    if not text[i - 1].isspace():
                        # a nested inline macro (`xref:#id[...]`): skip past its own close
                        depth: int = 1
                        i += 1
                        while i < len(text) and depth > 0:
                            depth += (text[i] == "[") - (text[i] == "]")
                            i += 1
                        continue
                    close: int = text.find("]", i)
                    if close != -1 and text[close - 1] != "\\":
                        yield (line.num, i + 1,
                               "bare '[' inside a footnote truncates it: Asciidoctor ends "
                               "the footnote text at the first unescaped ']'. Escape the "
                               "closing bracket, as in '[sic\\]'")
                    break
                i += 1


# Serves internal-references-with-xref (§internal-references-with-xref): an
# empty-bracket reference `xref:#id[]` inherits its visible text from the
# target's reference text. A section supplies its title, and a block-leading
# `[[id,reftext]]` anchor supplies its reftext, but an anchor sitting mid-text
# supplies nothing to the empty-bracket form and a bare `[[id]]` never does.
# Asciidoctor then prints the raw id in brackets -- a link that reads
# `[break-even-threshold]` -- and its render pass does NOT warn (verified
# empirically: converts with exit 0 and no message). This rule renders the
# document and flags every reference whose visible text is exactly its bracketed
# id, the signature of that defect, at the source `xref:#id[]` or `<<id>>` that
# produced it. The fix is explicit link text: `xref:#id[the term]`.

BARE_ID_LINK_RE = re.compile(
    r'<a href="#([A-Za-z0-9_-]+)"[^>]*>\[([A-Za-z0-9_-]+)\]</a>')
EMPTY_XREF_RE = re.compile(r"xref:#([A-Za-z0-9_-]+)\[\]")
BARE_ANGLE_RE = re.compile(r"<<([A-Za-z0-9_-]+)>>")


def rule_bare_id_xref(doc: Document) -> Iterator[Finding]:
    try:
        proc = subprocess.run(
            ["asciidoctor", "--out-file", "-", doc.path],
            capture_output=True, text=True,
        )
    except OSError:
        return
    bare = {m.group(1) for m in BARE_ID_LINK_RE.finditer(proc.stdout)
            if m.group(1) == m.group(2)}
    # A reference to a bibliography anchor renders as its bracketed id by
    # AsciiDoc convention (asciidoctor assigns `[[[id]]]` the xreflabel
    # `[id]`), so that rendering is correct, not a missing reference text.
    bare -= source_analysis(doc).bib_ids
    if not bare:
        return
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for rx in (EMPTY_XREF_RE, BARE_ANGLE_RE):
            for m in rx.finditer(masked):
                if m.group(1) in bare:
                    yield (line.num, m.start() + 1,
                           f"Cross-reference to {m.group(1)!r} renders as the raw "
                           f"id '[{m.group(1)}]': its anchor gives the empty-bracket "
                           f"form no reference text. Supply explicit link text, such "
                           f"as xref:#{m.group(1)}[the term] "
                           f"(§internal-references-with-xref)")


# ============================================================================
# Source citations -- verification rules
# ============================================================================
#
# The deterministic slice of the source-citation apparatus, over the parsed
# model built above. Layer 1 is pure shape: the footnote grammar, the entry
# classes, and the closed list (every citation resolves to an entry, every
# entry is cited). Layer 2 reaches outside the document: the archived file
# exists and hashes to the recorded SHA-256, its bytes are pinned by git when
# the document itself is committed, and every verbatim quote occurs in the
# text extracted from its archived source. The semantic layer -- does the
# source actually SUPPORT the claim -- needs a reader, not a linter, and is
# owned by the guideline's AI-verification protocol (§verify-citations).
#
# Two rule pairs share one detector each and differ only in registered
# severity: source-pinned/-draft (git findings gate the run only when the
# document is committed-clean, i.e. "pinned"; while drafting they are
# warnings) and source-quote/-unverifiable (a quote that IS checkable and
# absent gates; content nothing can extract text from only warns). The exit
# code gates on `error` findings alone, so the warning halves never block.

def rule_citation_footnote_format(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    seen: Set[str] = set()
    for cf in ana.citations:
        if cf.is_reuse:
            continue
        if cf.id:
            if cf.id in seen:
                yield (cf.line, cf.start_col,
                       f"Duplicate citation footnote id {cf.id!r}: a later "
                       f"re-citation is written footnote:{cf.id}[] with "
                       f"empty brackets (§citation-footnotes)")
            seen.add(cf.id)
        if cf.parse_error:
            col, detail = cf.parse_error
            yield (cf.line, col,
                   "Citation footnote doesn't match "
                   "'<<bib-anchor>>, LOCATOR: \"+QUOTE+\"' with sources "
                   "separated by '; ' and ']' inside a quote escaped as "
                   f"'\\]': {detail} (§citation-footnotes)")


# A render-integrity backstop like orphan-continuation: a prose line that
# contains ':: ' parses as a description-list item, so a sentence mentioning
# the marker inline -- "the form `Key:: value`" -- silently becomes a bold
# term with an indented definition, splitting the code span it sits in.
# Asciidoctor converts it without a warning. The precise signature of the
# accident is an odd number of backticks before the '::', which means the
# split lands inside an inline code span; a deliberate description list
# never has that.
DLIST_TERM_RE = re.compile(r"^(.+?)::(?:\s|$)")


def rule_split_code_dlist(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    for line in _prose(doc):
        if _in_bib(ana, line.num):
            continue
        m = DLIST_TERM_RE.match(line.text)
        if m and m.group(1).count("`") % 2 == 1:
            yield (line.num, len(m.group(1)) + 1,
                   "':: ' inside an inline code span turns the line into a "
                   "description-list item and splits the span; rephrase so "
                   "the '::' ends the span or drop the trailing space")


# The sibling accident: an anchor written inside a monospaced span still
# registers as a live anchor, so `[[sources]]` renders as an empty span
# with an invisible anchor where the literal text was meant. A footnote
# macro in a span fires the same way -- `footnote:id[]` becomes a live
# reuse mark instead of the literal text. Asciidoctor converts both
# without a warning. The passthrough form `+...+` shows them literally.
# (A live `link:` macro in a span is left alone: the About the Document
# sections write monospaced clickable file links with it on purpose.)
def rule_anchor_in_code_span(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for m in CODE_SPAN_RE.finditer(line.text):
            inner = m.group(0).strip("`")
            if inner.startswith("+") and inner.endswith("+"):
                continue
            if "[[" in inner:
                yield (line.num, m.start() + 1,
                       "An anchor inside a monospaced span registers as a "
                       "live anchor and renders nothing; write the literal "
                       "as `+[[...]]+`")
            if FOOTNOTE_OPEN_RE.search(inner):
                yield (line.num, m.start() + 1,
                       "A footnote macro inside a monospaced span registers "
                       "as a live footnote instead of literal text; write "
                       "the literal as `+footnote:...[...]+`")


# A render-integrity backstop: without a source-space after an inline
# monospaced span, Asciidoctor can fail to recognize the span's closing
# delimiter and render both backticks literally. The footnote itself still
# expands, so the rendered-macro backstop below cannot detect the damage.
def rule_footnote_after_code_span(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for span in CODE_SPAN_RE.finditer(line.text):
            suffix = line.text[span.end():]
            if FOOTNOTE_OPEN_RE.match(suffix):
                yield (line.num, span.end() + 1,
                       "A footnote immediately after a monospaced span makes "
                       "Asciidoctor render the backticks literally; insert a "
                       "space before the footnote macro")


# The same accident one character further out, where the span DOES close.
# A monospaced URL still autolinks, and Asciidoctor ends an autolink target
# only at whitespace or a bracket -- a backtick doesn't stop it, and the
# quotes substitution has already turned the span into `</code>` by the time
# the macro substitution runs. So a monospaced URL glued to the text after it
# lets the target run through the span's own closing delimiter and on into
# whatever macro follows: `` `https://host/`.footnote:id[...] `` renders as
# ONE link whose target is `https://host/</code>.footnote:id` and whose link
# TEXT is the footnote's text, spilled inline into the sentence. The footnote
# is consumed rather than left literal, so the rendered-macro backstop below
# finds no stray `footnote:` to report, and Asciidoctor converts with exit 0
# and no message (verified empirically). A `[` reached without crossing a
# backtick is the deliberate `https://host/[Link text^]` macro, which
# link-text owns. The fix is a space before the macro, or the passthrough
# span `+...+`, whose content doesn't autolink.
MONO_URL_RE = re.compile(r"^(?:https?|file|ftp|irc)://[^\s\[\]]*$")
AUTOLINK_TAIL_RE = re.compile(r"[^\s\[\]]*\[")


def rule_autolink_after_code_span(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for span in CODE_SPAN_RE.finditer(line.text):
            inner = span.group(0).strip("`")
            if inner.startswith("+") and inner.endswith("+"):
                continue  # a passthrough span: its content doesn't autolink
            if not MONO_URL_RE.match(inner):
                continue
            if AUTOLINK_TAIL_RE.match(line.text, span.end()):
                yield (line.num, span.end() + 1,
                       "A monospaced URL glued to the text after it lets the "
                       "autolink target run past the closing backtick and "
                       "swallow the following macro's brackets as link text, "
                       "so that macro is dropped and its body renders inline; "
                       "insert a space, or write the address as `+...+`")


# Serves footnote-punctuation (§footnote-punctuation): every footnote's text
# -- ordinary or citation -- ends with a period, so no footnote reads as
# truncated. A reuse (`footnote:id[]`) has no text of its own and is exempt.
def rule_footnote_dot(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        masked = _mask_code(line.text)
        for om in FOOTNOTE_OPEN_RE.finditer(masked):
            end = _macro_end(line.text, om.end())
            if end == -1:
                continue  # unterminated macro; other rules report it
            body = line.text[om.end():end]
            if body and not body.endswith("."):
                yield (line.num, om.start() + 1,
                       "Footnote text doesn't end with a period "
                       "(§footnote-punctuation)")


def _entry_schema(entry: BibEntry) -> Optional[List[Tuple[str, str]]]:
    """The entry's canonical ordered (key, shape) sequence, assembled from
    the common, type, status, and class dimensions, or None when the Type
    doesn't resolve. A request-class entry takes no type."""
    ordered: List[Tuple[str, str]] = [("Title", "text")]
    if entry.cls == "request":
        return ordered + CLASS_SCHEMA["request"][0]
    type_name = entry.fields.get("Type", ("", 0))[0]
    schema = TYPE_SCHEMA.get(type_name)
    if schema is None:
        return None
    ordered.append(("Type", "text"))
    ordered += schema[0] + schema[1]
    present = {key for key, _shape in ordered}
    ordered += [pair for pair in STATUS_KEYS if pair[0] not in present]
    cls_schema = CLASS_SCHEMA.get(entry.cls)
    if cls_schema:
        ordered += cls_schema[0] + cls_schema[1]
    return ordered


def rule_bibliography_format(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    for line in _prose(doc):
        if line.text.strip() == "[bibliography]":
            yield (line.num, 1,
                   "Native AsciiDoc '[bibliography]' attribute: its "
                   "rendering bypasses the anchors' reference labels, so "
                   "the bibliography is marked with the '[[sources]]' "
                   "anchor instead (§bibliography-markup)")
    if ana.citations and not ana.bib_attr_line:
        yield (len(doc.lines), 1,
               "Document cites sources but has no bibliography section "
               "marked '[[sources]]' to resolve them against "
               "(§closed-source-list)")
    for line_num, col, anchor_id in ana.stray_triple_anchors:
        yield (line_num, col,
               f"Triple-bracket anchor '[[[{anchor_id}]]]': a bibliography "
               f"entry anchors with the double form '[[id,Label]]' "
               f"(§bibliography-markup)")
    if not ana.bib_attr_line:
        return
    if not ana.bib_heading_line:
        yield (ana.bib_attr_line, 1,
               "'[[sources]]' anchor has no section heading under it "
               "(§bibliography-markup)")
    else:
        heading_text = re.sub(r"^=+\s+", "",
                              doc.lines[ana.bib_heading_line - 1].text)
        if heading_text.strip() != "Sources":
            yield (ana.bib_heading_line, 1,
                   f"The bibliography section is titled 'Sources', not "
                   f"{heading_text.strip()!r} (§bibliography-markup)")
        for num in range(ana.bib_attr_line + 1, ana.bib_heading_line):
            if doc.lines[num - 1].text.strip():
                yield (ana.bib_attr_line, 1,
                       "'[[sources]]' anchor is detached from its section "
                       "heading (§bibliography-markup)")
                break
        for num, _level in doc.headings:
            if num > ana.bib_heading_line:
                yield (num, 1,
                       "Section after the bibliography: the bibliography is "
                       "the document's last section (§bibliography-markup)")
        for line_num, _text in ana.bad_bib_lines:
            yield (line_num, 1,
                   "Line inside the bibliography is neither a "
                   "'. [[id,Label]]_Label_' item line nor a 'Key:: value' "
                   "field line (§bibliography-markup)")
    seen_labels: Dict[str, int] = {}
    for entry in ana.entries:
        if not KEBAB_ID_RE.fullmatch(entry.id):
            yield (entry.line, 1,
                   f"bibliography id {entry.id!r} should be lowercase "
                   f"kebab-case (§source-identity)")
        if not entry.label:
            yield (entry.line, 1,
                   "Bibliography entry declares no reference label; write "
                   "'[[id,Reference Label]]' so every reference renders "
                   "the label (§bibliography-markup)")
        elif entry.label == entry.id:
            yield (entry.line, 1,
                   f"Reference label {entry.label!r} repeats the anchor id; "
                   f"declare a readable label - an author and a year, a "
                   f"short title, a standard's number (§bibliography-markup)")
        elif entry.label in seen_labels:
            yield (entry.line, 1,
                   f"Reference label {entry.label!r} is already used by the "
                   f"entry on line {seen_labels[entry.label]}; labels are "
                   f"unique among the entries (§bibliography-markup)")
        else:
            seen_labels[entry.label] = entry.line
        if entry.label and entry.item_text != f"_{entry.label}_":
            yield (entry.line, 1,
                   f"Entry item line carries only the italicized reference "
                   f"label: write '. [[{entry.id},{entry.label}]]"
                   f"_{entry.label}_' and give every field its own "
                   f"'Key:: value' line (§bibliography-markup)")
        if not entry.style_line:
            yield (entry.line, 1,
                   "Entry fields open with a '[horizontal.source-fields]' "
                   "line directly under the item line (§bibliography-markup)")
        for key, dup_line in entry.dup_keys:
            yield (dup_line, 1,
                   f"Duplicate field {key!r}; each field appears once per "
                   f"entry (§bibliography-markup)")
        title_field = entry.fields.get("Title")
        if title_field and title_field[0] == entry.label:
            yield (title_field[1], 1,
                   "Title repeats the reference label; omit the Title field "
                   "when the label already gives the title "
                   "(§bibliography-markup)")
        if entry.cls == "none":
            yield (entry.line, 1,
                   "Entry declares no reachability class: state the fields "
                   "of exactly one class - archived file (Archived as, "
                   "SHA-256), web (URL, Accessed), request (Request "
                   "of, By), or not archived (Not archived) "
                   "(§source-identity)")
            continue
        if entry.cls == "ambiguous":
            yield (entry.line, 1,
                   "Entry mixes the fields of two reachability classes; "
                   "exactly one class applies (§source-identity)")
            continue
        type_field = entry.fields.get("Type")
        if entry.cls == "request":
            if type_field:
                yield (type_field[1], 1,
                       "A request-class entry takes no Type "
                       "(§source-identity)")
        elif type_field is None:
            yield (entry.line, 1,
                   "Entry declares no 'Type::'; pick one from the type "
                   "catalog, with 'Other' as the fallback "
                   "(§source-identity)")
            continue
        elif type_field[0] not in TYPE_SCHEMA:
            yield (type_field[1], 1,
                   f"Unknown type {type_field[0]!r}; the type catalog, "
                   f"including the fallback 'Other', is defined in the "
                   f"guideline (§source-identity)")
            continue
        ordered = _entry_schema(entry)
        if ordered is None:
            continue
        order_index = {key: i for i, (key, _shape) in enumerate(ordered)}
        shape_of = dict(ordered)
        known = ", ".join(key for key, _shape in ordered)
        required = list(CLASS_SCHEMA[entry.cls][0])
        if entry.cls != "request":
            required = TYPE_SCHEMA[type_field[0]][0] + required
        required_keys = {key for key, _shape in required}
        previous_index = -1
        for key, (value, line_num) in entry.fields.items():
            if key not in order_index:
                yield (line_num, 1,
                       f"{key!r} isn't a field of this entry; its fields "
                       f"are: {known} (§source-identity)")
                continue
            index = order_index[key]
            if index < previous_index:
                yield (line_num, 1,
                       f"Field {key!r} is out of order; the entry's field "
                       f"order is: {known} (§bibliography-markup)")
            previous_index = max(previous_index, index)
            if value == "unknown":
                if key in CLASS_SIGNATURE:
                    yield (line_num, 1,
                           f"{key!r} can't be unknown: the class fields "
                           f"record the author's own acts and computations "
                           f"(§source-identity)")
                elif key not in required_keys:
                    yield (line_num, 1,
                           f"Optional field {key!r} with the value "
                           f"'unknown'; omit an unknown optional field "
                           f"(§source-identity)")
                continue
            shape_name = shape_of[key]
            shape = SHAPES[shape_name]
            if shape and not shape[0].match(value):
                shown = value if len(value) <= 40 else value[:37] + "..."
                yield (line_num, 1,
                       f"{key!r} value {shown!r} isn't {shape[1]} "
                       f"(§source-identity)")
        for key, _shape in required:
            if key not in entry.fields:
                yield (entry.line, 1,
                       f"Entry lacks the required field '{key}::' "
                       f"(§source-identity)")
        if (entry.cls != "request"
                and type_field[0] in STATUS_REQUIRED_TYPES
                and "Status" not in entry.fields):
            yield (entry.line, 1,
                   f"A {type_field[0]} entry states 'Status::': its "
                   f"standing - draft or final - decides what it can "
                   f"support (§source-status)")


def rule_closed_source_list(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    cited = {ref.anchor for cf in ana.citations for ref in cf.sources}
    for entry in ana.entries:
        if entry.id not in cited:
            yield (entry.line, 1,
                   f"Bibliography entry {entry.id!r} is cited by no citation "
                   f"footnote; every listed source substantiates at least "
                   f"one claim (§closed-source-list)")
    for cf in ana.citations:
        for ref in cf.sources:
            if ref.anchor not in ana.bib_ids:
                yield (cf.line, ref.col,
                       f"Citation references {ref.anchor!r}, which is not a "
                       f"bibliography entry (§closed-source-list)")


def _doc_dir(doc: Document) -> str:
    return os.path.dirname(os.path.abspath(doc.path)) or "."


def _file_sha256(path: str, cache: Dict[str, str]) -> str:
    if path not in cache:
        digest = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                digest.update(chunk)
        cache[path] = digest.hexdigest()
    return cache[path]


def rule_source_file(doc: Document) -> Iterator[Finding]:
    ana = source_analysis(doc)
    base = _doc_dir(doc)
    for entry in ana.entries:
        if entry.cls != "archived-file":
            continue
        full = os.path.normpath(os.path.join(base, entry.path))
        if not os.path.isfile(full):
            yield (entry.line, 1,
                   f"Archived source file {entry.path!r} doesn't exist "
                   f"relative to the document (§source-identity)")
            continue
        actual = _file_sha256(full, ana.sha_cache)
        if actual != entry.sha256:
            yield (entry.line, 1,
                   f"Archived source {entry.path!r} hashes to "
                   f"{actual[:12]}..., not the recorded SHA-256 "
                   f"{entry.sha256[:12]}...; the file changed after it was "
                   f"cited (§source-identity)")


def _git(base: str, *args: str) -> Optional[str]:
    try:
        proc = subprocess.run(["git", "-C", base, *args],
                              capture_output=True, text=True)
    except OSError:
        return None
    return proc.stdout if proc.returncode == 0 else None


def _doc_mode(doc: Document) -> str:
    """'pinned' when the linted document is git-tracked and clean, 'draft'
    when it sits in a repository in any other state, 'nogit' outside one.
    Every git call is pathspec-scoped, so the throwaway files other engines
    write beside the source never leak into the answer."""
    ana = source_analysis(doc)
    if ana.mode:
        return ana.mode
    base = _doc_dir(doc)
    name = os.path.basename(doc.path)
    if _git(base, "rev-parse", "--is-inside-work-tree") is None:
        ana.mode = "nogit"
    elif (_git(base, "ls-files", "--error-unmatch", "--", name) is not None
          and (_git(base, "status", "--porcelain", "--", name) or "") == ""):
        ana.mode = "pinned"
    else:
        ana.mode = "draft"
    return ana.mode


def _pinned_findings(doc: Document) -> List[Finding]:
    ana = source_analysis(doc)
    if ana.pinned_findings is not None:
        return ana.pinned_findings
    base = _doc_dir(doc)
    findings: List[Finding] = []
    for entry in ana.entries:
        if entry.cls != "archived-file":
            continue
        if not os.path.isfile(os.path.normpath(os.path.join(base,
                                                            entry.path))):
            continue  # rule_source_file already reports the absence
        if _git(base, "ls-files", "--error-unmatch", "--",
                entry.path) is None:
            findings.append((entry.line, 1,
                             f"Archived source {entry.path!r} isn't tracked "
                             f"by git, so the citation isn't pinned to "
                             f"committed bytes (§source-identity)"))
            continue
        status = _git(base, "status", "--porcelain", "--", entry.path)
        if status is not None and status.strip():
            findings.append((entry.line, 1,
                             f"Archived source {entry.path!r} has "
                             f"uncommitted changes; commit it so the cited "
                             f"bytes are pinned (§source-identity)"))
    ana.pinned_findings = findings
    return findings


def rule_source_pinned(doc: Document) -> Iterator[Finding]:
    if _doc_mode(doc) == "pinned":
        yield from _pinned_findings(doc)


def rule_source_pinned_draft(doc: Document) -> Iterator[Finding]:
    if _doc_mode(doc) == "draft":
        yield from _pinned_findings(doc)


def _xml_paragraph_text(data: bytes) -> str:
    """Visible text of an OOXML part: per paragraph element (`w:p` in
    WordprocessingML, `a:p` in DrawingML) the text runs are concatenated
    WITHOUT separators, because one word routinely splits across runs;
    breaks and tabs become spaces; paragraphs join with spaces."""
    root = ET.fromstring(data)
    chunks: List[str] = []
    for para in root.iter():
        if para.tag.rsplit("}", 1)[-1] != "p":
            continue
        run: List[str] = []
        for el in para.iter():
            tag = el.tag.rsplit("}", 1)[-1]
            if tag == "t" and el.text:
                run.append(el.text)
            elif tag in ("br", "tab", "cr"):
                run.append(" ")
        chunks.append("".join(run))
    return " ".join(chunks)


class _HTMLText(HTMLParser):
    """Visible text of an HTML document (an archived web-source snapshot):
    script and style contents are dropped, everything else concatenates."""

    def __init__(self) -> None:
        super().__init__()
        self.parts: List[str] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in ("script", "style"):
            self._skip += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style") and self._skip:
            self._skip -= 1

    def handle_data(self, data: str) -> None:
        if not self._skip:
            self.parts.append(data)


def _xlsx_text(zf: "zipfile.ZipFile") -> str:
    texts: List[str] = []
    names = zf.namelist()
    if "xl/sharedStrings.xml" in names:
        root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
        for si in root:
            texts.append("".join(el.text for el in si.iter()
                                 if el.tag.rsplit("}", 1)[-1] == "t"
                                 and el.text))
    for name in sorted(names):
        if not (name.startswith("xl/worksheets/") and name.endswith(".xml")):
            continue
        root = ET.fromstring(zf.read(name))
        for cell in root.iter():
            if cell.tag.rsplit("}", 1)[-1] == "is":  # inline string
                texts.append("".join(el.text for el in cell.iter()
                                     if el.tag.rsplit("}", 1)[-1] == "t"
                                     and el.text))
    return " ".join(texts)


IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp", ".gif",
              ".webp")


# tesseract OCR requests every preferred language that the local install
# actually carries, so image sources that hold non-English text (for example
# a Polish call summary) are read with the matching language pack. A
# preferred language whose trained data is absent is dropped, which downgrades
# an affected quote to a warning instead of failing the OCR pass outright.
#
# DEPLOYMENT NOTE: this script is meant to move into the dockerized
# environment where ALL tesseract language packs are preinstalled. There
# `_ocr_langs()` resolves to the full preferred set; run locally it falls back
# to whatever language data happens to be installed.
_OCR_PREFERRED = ("eng", "pol")
_ocr_langs_value: Optional[str] = None


def _ocr_langs() -> str:
    """The `-l` value for tesseract: the preferred languages the local install
    carries, joined with '+', or 'eng' as a last resort."""
    global _ocr_langs_value
    if _ocr_langs_value is None:
        installed: set = set()
        try:
            proc = subprocess.run(["tesseract", "--list-langs"],
                                  capture_output=True, text=True)
            if proc.returncode == 0:
                installed = {ln.strip() for ln in proc.stdout.splitlines()
                             if ln.strip() and " " not in ln.strip()}
        except OSError:
            pass
        chosen = [lang for lang in _OCR_PREFERRED if lang in installed]
        _ocr_langs_value = "+".join(chosen) if chosen else "eng"
    return _ocr_langs_value


def _extract_source_text(path: str) -> Tuple[Optional[str], str]:
    """(text, "") when text is extractable from the archived source, else
    (None, why-not). Stdlib-only except PDF, which uses the required
    `pdftotext` binary. Never raises: an unreadable source downgrades the
    quote check to a warning instead of crashing the run.

    The XML inside OOXML containers is parsed with the stdlib parser on
    purpose (the linter takes no third-party imports). The inputs are files
    the author archived into the document's own repository, not attacker
    traffic, and a hostile container is contained anyway: expat's built-in
    entity-expansion limits and any parse failure land in the except clause
    below, i.e. in the 'unverifiable' warning path."""
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".pdf":
            if shutil.which("pdftotext") is None:
                return None, "pdftotext is not on PATH"
            proc = subprocess.run(["pdftotext", "-enc", "UTF-8", path, "-"],
                                  capture_output=True, text=True)
            if proc.returncode != 0:
                return None, "pdftotext failed on the file"
            return proc.stdout, ""
        if ext in (".docx", ".pptx"):
            with zipfile.ZipFile(path) as zf:
                if ext == ".docx":
                    parts = [n for n in ("word/document.xml",
                                         "word/footnotes.xml",
                                         "word/endnotes.xml")
                             if n in zf.namelist()]
                else:
                    parts = sorted(
                        n for n in zf.namelist()
                        if (n.startswith("ppt/slides/slide")
                            or n.startswith("ppt/notesSlides/"))
                        and n.endswith(".xml"))
                return " ".join(_xml_paragraph_text(zf.read(p))
                                for p in parts), ""
        if ext == ".xlsx":
            with zipfile.ZipFile(path) as zf:
                # Numeric cell values are not extracted: quote the labels
                # around a number, not the raw number alone.
                return _xlsx_text(zf), ""
        if ext in (".odt", ".ods", ".odp"):
            with zipfile.ZipFile(path) as zf:
                return " ".join(
                    ET.fromstring(zf.read("content.xml")).itertext()), ""
        if ext in (".html", ".htm", ".xhtml"):
            with open(path, encoding="utf-8") as f:
                parser = _HTMLText()
                parser.feed(f.read())
                return " ".join(parser.parts), ""
        if ext == ".eml":
            with open(path, "rb") as f:
                msg = email.message_from_binary_file(
                    f, policy=email.policy.default)
            chunks = [str(msg.get(h, ""))
                      for h in ("Subject", "From", "To", "Date")]
            for part in msg.walk():
                ctype = part.get_content_type()
                if ctype == "text/plain":
                    chunks.append(part.get_content())
                elif ctype == "text/html":
                    parser = _HTMLText()
                    parser.feed(part.get_content())
                    chunks.append(" ".join(parser.parts))
            return " ".join(chunks), ""
        if ext in IMAGE_EXTS:
            proc = subprocess.run(["tesseract", path, "-", "-l", _ocr_langs()],
                                  capture_output=True, text=True)
            if proc.returncode != 0:
                return None, "tesseract failed on the image"
            return proc.stdout, ""
        with open(path, encoding="utf-8") as f:
            return f.read(), ""
    except UnicodeDecodeError:
        return None, "binary content"
    except (zipfile.BadZipFile, ET.ParseError, KeyError, LookupError,
            ValueError, OSError):
        return None, f"malformed or unreadable {ext or 'file'} container"


def _norm_ws(text: str) -> str:
    return " ".join(text.split())


def _quote_results(doc: Document) -> List[Tuple[Finding, str]]:
    """(finding, kind) pairs for the quote checks; kind is 'fail' for a
    checkable quote that is absent and 'unverifiable' for content no text
    can be extracted from. The comparison is case-sensitive -- the quote is
    verbatim -- with whitespace runs collapsed on both sides."""
    ana = source_analysis(doc)
    if ana.quote_results is not None:
        return ana.quote_results
    base = _doc_dir(doc)
    entry_by_id = {e.id: e for e in ana.entries}
    text_cache: Dict[str, Tuple[Optional[str], str]] = {}
    results: List[Tuple[Finding, str]] = []
    stats = {"checked": 0, "verified": 0, "ocr_checked": 0, "ocr_verified": 0}
    for cf in ana.citations:
        for ref in cf.sources:
            entry = entry_by_id.get(ref.anchor)
            if entry is None or entry.cls != "archived-file" or not ref.quote:
                continue
            full = os.path.normpath(os.path.join(base, entry.path))
            if not os.path.isfile(full):
                continue  # rule_source_file already reports the absence
            if full not in text_cache:
                text_cache[full] = _extract_source_text(full)
            text, why_not = text_cache[full]
            is_image = os.path.splitext(full)[1].lower() in IMAGE_EXTS
            stats["checked"] += 1
            stats["ocr_checked"] += is_image
            if text is None:
                results.append(((cf.line, ref.col,
                                 f"Quote from {entry.path!r} isn't "
                                 f"mechanically verifiable ({why_not}); "
                                 f"verify it by eye (§quote-and-locator)"),
                                "unverifiable"))
            elif _norm_ws(ref.quote) in _norm_ws(text):
                stats["verified"] += 1
                stats["ocr_verified"] += is_image
            else:
                # An OCR miss on an image is lossy evidence, not proof of a
                # broken quote, so it warns instead of gating the run.
                if is_image:
                    results.append(((cf.line, ref.col,
                                     f"Quote not found in the OCR text of "
                                     f"{entry.path!r} (OCR is lossy); "
                                     f"verify it by eye "
                                     f"(§quote-and-locator)"),
                                    "unverifiable"))
                else:
                    results.append(((cf.line, ref.col,
                                     f"Quote not found verbatim in "
                                     f"{entry.path!r} (whitespace-"
                                     f"insensitive search); the claim's "
                                     f"support is broken "
                                     f"(§quote-and-locator)"),
                                    "fail"))
    ana.quote_results = results
    ana.quote_stats = stats
    return results


def rule_source_quote(doc: Document) -> Iterator[Finding]:
    yield from (f for f, kind in _quote_results(doc) if kind == "fail")


def rule_source_quote_unverifiable(doc: Document) -> Iterator[Finding]:
    yield from (f for f, kind in _quote_results(doc)
                if kind == "unverifiable")


# A deterministic tripwire for the overreach class the quote check can't see:
# a reported claim that asserts a count, a universal, an aggregate, or a
# superlative that none of its quotes state. It compares the "assertive" words
# of the claim against those of its cited quotes and warns on a claim word no
# quote carries. It doesn't judge entailment -- that is the verification pass
# of §verify-citations -- it points that pass at the sentences most likely to
# overstate their source. Two exclusions keep the signal generic and quiet:
# digits are ignored, so a date or a budget figure never trips it, and an
# inferred claim is ignored, because an inference is allowed to synthesize
# beyond any single premise (§claim-classes). The word set carries no project
# vocabulary, so the rule travels unchanged to any document.
_ASSERTIVE_WORDS = frozenset("""
two three four five six seven eight nine ten eleven twelve thirteen fourteen
fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty
seventy eighty ninety hundred thousand million billion dozen
all every each both most only
mean average total aggregate combined overall sum
best worst largest smallest highest lowest greatest fewest maximum minimum least
""".split())
_OVERREACH_QUOTE_RE = re.compile(r'"\+(.*?)\+"')
_OVERREACH_WORD_RE = re.compile(r"[a-z]+")


def _assertive_words(text: str) -> set:
    return {w for w in _OVERREACH_WORD_RE.findall(text.lower())
            if w in _ASSERTIVE_WORDS}


def _footnote_quote_words(body: str) -> set:
    words: set = set()
    for qm in _OVERREACH_QUOTE_RE.finditer(body):
        words |= _assertive_words(qm.group(1))
    return words


def rule_citation_overreach(doc: Document) -> Iterator[Finding]:
    # An inline-code span holds illustrative markup, not a live citation: a
    # '`+footnote:id[]+`' shown as an example must not be read as a real
    # footnote. Code spans are blanked first, as the other macro rules do. A
    # citation quote '"+...+"' is not a backtick span, so it survives the
    # blanking and its words stay readable.
    def blanked(text: str) -> str:
        return CODE_SPAN_RE.sub(lambda mm: " " * len(mm.group(0)), text)
    # A reuse 'footnote:id[]' shares the quotes of its definition, so the
    # defining quote words and the inferred flag are indexed by id first.
    def_words: Dict[str, set] = {}
    def_inferred: Dict[str, bool] = {}
    for line in _prose(doc):
        text = blanked(line.text)
        for m in FOOTNOTE_OPEN_RE.finditer(text):
            close = _macro_end(text, m.end())
            if close == -1:
                continue
            body = text[m.end():close]
            if not body.strip():
                continue  # a reuse; its quotes live in the definition
            fid = m.group(1)
            def_words.setdefault(fid, set()).update(_footnote_quote_words(body))
            if body.lstrip().startswith(CITE_INFER_PREFIX):
                def_inferred[fid] = True
    for line in _prose(doc):
        text = blanked(line.text)
        prev_end = -1
        for m in FOOTNOTE_OPEN_RE.finditer(text):
            close = _macro_end(text, m.end())
            if close == -1:
                continue
            claim = text[prev_end + 1:m.start()]
            claim_start = prev_end + 1
            prev_end = close
            fid = m.group(1)
            body = text[m.end():close]
            if (body.lstrip().startswith(CITE_INFER_PREFIX)
                    or def_inferred.get(fid, False)):
                continue  # an inference may synthesize beyond its premises
            quote_words = (_footnote_quote_words(body) if body.strip()
                           else def_words.get(fid, set()))
            for word in sorted(_assertive_words(claim) - quote_words):
                wm = re.search(rf"\b{re.escape(word)}\b", claim, re.IGNORECASE)
                col = claim_start + (wm.start() if wm else 0) + 1
                yield (line.num, col,
                       f"claim asserts {word!r} but no quote cited here "
                       f"contains it: confirm the source states it, or mark "
                       f"the claim inferred or author-supplied "
                       f"(§verify-citations)")


# ============================================================================
# ASCII diagrams -- character hygiene
# ============================================================================
#
# Serves ascii-diagrams (§ascii-diagrams): a clean diagram uses one consistent
# set of box characters. These checks run only inside literal (`....`) blocks,
# where diagrams live. Deep alignment verification is unreliable and left out;
# the checks below catch the defects that actually break a diagram -- a tab or
# trailing space silently shifts a column, and mixing ASCII box-drawing
# (`+ - |`) with Unicode box-drawing (`─ │ ┌`) inside one diagram breaks the
# "one consistent set of characters" rule. A diagram drawn entirely in either
# set passes; only a mix is flagged.

UNICODE_BOX_RE = re.compile(r"[─-╿]")            # U+2500..257F box-drawing
ASCII_BOX_RE = re.compile(r"\+[-|]|[-|]\+")      # ASCII corner/junction signature


def rule_diagram_tabs(doc: Document) -> Iterator[Finding]:
    for line in doc.lines:
        if line.block == "literal" and "\t" in line.text:
            yield (line.num, line.text.index("\t") + 1,
                   "Tab in an ASCII diagram shifts alignment and must be "
                   "spaces (§ascii-diagrams)")


def rule_diagram_trailing_space(doc: Document) -> Iterator[Finding]:
    for line in doc.lines:
        if line.block == "literal" and line.text != line.text.rstrip():
            yield (line.num, len(line.text.rstrip()) + 1,
                   "trailing whitespace in an ASCII diagram (§ascii-diagrams)")


def rule_verbatim_flush_left(doc: Document) -> Iterator[Finding]:
    # A verbatim block whose every content line is indented renders with a
    # blank first column inside the block's own padding, so the content sits
    # visibly off-center. The left inset belongs to the theme and stylesheet,
    # not to spaces baked into the content: the shallowest line of a listing
    # (`----`) or literal (`....`) block must start at column 1.
    def report(block: List[Line]) -> Iterator[Finding]:
        content = [ln for ln in block[1:-1] if ln.text.strip()]
        if not content:
            return
        indent = min(len(ln.text) - len(ln.text.lstrip(" ")) for ln in content)
        if indent >= 1:
            first = min(content, key=lambda ln: ln.num)
            yield (first.num, 1,
                   f"verbatim block content is indented {indent} column(s); "
                   f"dedent it so the shallowest line starts at column 1 "
                   f"(§ascii-diagrams)")

    run: List[Line] = []
    for line in doc.lines:
        if line.block in ("listing", "literal") and \
                (not run or run[-1].block == line.block):
            run.append(line)
            continue
        if run:
            yield from report(run)
            run = []
        if line.block in ("listing", "literal"):
            run.append(line)
    if run:
        yield from report(run)


def rule_diagram_charset(doc: Document) -> Iterator[Finding]:
    # Group each contiguous literal block (one diagram) and flag it only when it
    # mixes the two box-drawing sets; a diagram drawn wholly in ASCII or wholly
    # in Unicode is consistent and passes.
    def report(block: List[Line]) -> Iterator[Finding]:
        if not any(UNICODE_BOX_RE.search(ln.text) for ln in block):
            return
        for ln in block:
            m = ASCII_BOX_RE.search(ln.text)
            if m:
                yield (ln.num, m.start() + 1,
                       "ASCII and Unicode box-drawing mixed in one diagram "
                       "instead of one consistent set (§ascii-diagrams)")
                return

    block: List[Line] = []
    for line in doc.lines:
        if line.block == "literal":
            block.append(line)
            continue
        if block:
            yield from report(block)
            block = []
    if block:
        yield from report(block)


# Serves ascii-diagrams (§ascii-diagrams): a box whose side drifts off its
# corners is an alignment defect a whole-block width check can't flag without
# false positives. This rule pairs each border line with the next and takes the
# columns their `+` corners share -- the box's outer corners, plus any junction
# that lines up top to bottom. Every line between the two borders that is a wall
# (a `|` or `+` at the left or right shared column) must carry a `|` or `+` at
# *every* shared column, so a side that slips off its corners is caught even when
# the two borders differ, as in a junction box (`+-----+` over `+--+--+`). A line
# with a wall at neither outer column is a connector, not a box side, and is
# skipped -- which keeps arrows and lifelines between stacked boxes from being
# flagged.


def _is_border_drawing(text: str) -> bool:
    return (text.strip() != "" and all(c in "+- " for c in text)
            and "+" in text and "-" in text)


def _plus_columns(text: str) -> List[int]:
    return [i for i, char in enumerate(text) if char == "+"]


def rule_diagram_box_alignment(doc: Document) -> Iterator[Finding]:
    def check(block: List[Line]) -> Iterator[Finding]:
        borders = [i for i, ln in enumerate(block) if _is_border_drawing(ln.text)]
        for top_i, bottom_i in zip(borders, borders[1:]):
            shared = sorted(set(_plus_columns(block[top_i].text))
                            & set(_plus_columns(block[bottom_i].text)))
            if not shared:
                continue
            left, right = shared[0], shared[-1]
            for ln in block[top_i + 1:bottom_i]:
                text = ln.text
                left_wall = left < len(text) and text[left] in "|+"
                right_wall = right < len(text) and text[right] in "|+"
                if not (left_wall or right_wall):
                    continue
                for col in shared:
                    if not (col < len(text) and text[col] in "|+"):
                        yield (ln.num, col + 1,
                               "Box wall is missing at its border "
                               f"column {col + 1} (§ascii-diagrams)")

    block: List[Line] = []
    for line in doc.lines:
        if line.block == "literal":
            block.append(line)
            continue
        if block:
            yield from check(block)
            block = []
    if block:
        yield from check(block)


# Serves ascii-diagrams (§ascii-diagrams): the dual of the box-alignment rule
# above. That rule checks walls against the columns two borders share; this one
# checks a border against the walls around it. A box corner is where a horizontal
# border meets a vertical wall, so every `+` on a border line must connect to a
# `|` or `+` directly above or directly below it. A border shifted off its walls
# leaves its corners hanging over empty space, which this flags even when the two
# borders share no column (so the alignment rule finds nothing to compare). The
# check runs only on "border-drawing" lines (made of `+`, `-`, and spaces), so a
# `+` inside literal text -- a `postgres+index` query in a `....` block -- is
# never mistaken for a corner. A vertical stroke that meets a corner may be a
# wall (`|`, `+`) or a vertical arrowhead (`^`, `v`): a loop that returns up
# into a box draws its corner under a `^`, and that arrowhead IS the connector.
# Without this, the rule fired only when a return edge happened to be unlabelled
# (a labelled edge like `+-- correct --+` carries letters, so it isn't a
# border-drawing line and is skipped) -- an inconsistency, not a real defect.

VERTICAL_CONNECTORS = "|+^v"


def rule_diagram_corner_support(doc: Document) -> Iterator[Finding]:
    def check(block: List[Line]) -> Iterator[Finding]:
        for i, ln in enumerate(block):
            if not _is_border_drawing(ln.text):
                continue
            above = block[i - 1].text if i > 0 else ""
            below = block[i + 1].text if i + 1 < len(block) else ""
            for col, char in enumerate(ln.text):
                if char != "+":
                    continue
                up = above[col] if col < len(above) else " "
                down = below[col] if col < len(below) else " "
                if up in VERTICAL_CONNECTORS or down in VERTICAL_CONNECTORS:
                    continue
                yield (ln.num, col + 1,
                       "Box corner has no wall directly above or below it "
                       "(§ascii-diagrams)")

    block: List[Line] = []
    for line in doc.lines:
        if line.block == "literal":
            block.append(line)
            continue
        if block:
            yield from check(block)
            block = []
    if block:
        yield from check(block)


# A connector junction may share a line with an arrow label or a node, as in
# ``+------> [destination] <+``. Such a line isn't a box border, so the corner
# rule above intentionally skips it. A `+` that touches a horizontal or
# vertical connector still represents a junction, however, and must join at
# least two segments. One attached segment means that the junction dangles:
# most often its vertical branch has drifted to another column. Arithmetic and
# literal plus signs are ignored because they touch no connector character.
HORIZONTAL_CONNECTORS = "-<>"


def rule_diagram_junction_support(doc: Document) -> Iterator[Finding]:
    def check(block: List[Line]) -> Iterator[Finding]:
        for i, line in enumerate(block):
            text = line.text
            above = block[i - 1].text if i > 0 else ""
            below = block[i + 1].text if i + 1 < len(block) else ""
            for col, char in enumerate(text):
                if char != "+":
                    continue
                left = col > 0 and text[col - 1] in HORIZONTAL_CONNECTORS
                right = (col + 1 < len(text)
                         and text[col + 1] in HORIZONTAL_CONNECTORS)
                up = col < len(above) and above[col] in VERTICAL_CONNECTORS
                down = col < len(below) and below[col] in VERTICAL_CONNECTORS
                attached = sum((left, right, up, down))
                if attached == 1:
                    yield (line.num, col + 1,
                           "Connector junction has only one attached segment; "
                           "align it with its vertical branch or remove the "
                           "dangling `+` (§ascii-diagrams)")

    block: List[Line] = []
    for line in doc.lines:
        if line.block == "literal":
            block.append(line)
            continue
        if block:
            yield from check(block)
            block = []
    if block:
        yield from check(block)


# Serves ascii-diagrams (§ascii-diagrams): a sequence diagram has no boxes, so
# the box rules above never look at it. Its invariant is that each participant's
# lifeline holds one fixed column down the whole diagram. This rule takes the
# lifeline columns -- those carrying a `|` on at least half the rows that have
# any `|` -- and flags a `|` in any other column, which is a lifeline that has
# drifted, usually because an arrow on that row was drawn a character too long or
# too short. It runs only on `|`-heavy blocks with no `+`, so box diagrams
# (handled above) and an incidental `|` in prose or a piped command are left
# alone.


def rule_diagram_lifeline_alignment(doc: Document) -> Iterator[Finding]:
    def check(block: List[Line]) -> Iterator[Finding]:
        if any("+" in ln.text for ln in block):
            return
        rows = [ln for ln in block if "|" in ln.text]
        if len(rows) < 5:
            return
        counts: Dict[int, int] = {}
        for ln in rows:
            for col, char in enumerate(ln.text):
                if char == "|":
                    counts[col] = counts.get(col, 0) + 1
        lifelines = {col for col, n in counts.items() if n >= len(rows) / 2}
        if len(lifelines) < 2:
            return
        for ln in rows:
            for col, char in enumerate(ln.text):
                if char == "|" and col not in lifelines:
                    yield (ln.num, col + 1,
                           "Lifeline is not aligned with the fixed column its "
                           "participant keeps (§ascii-diagrams)")

    block: List[Line] = []
    for line in doc.lines:
        if line.block == "literal":
            block.append(line)
            continue
        if block:
            yield from check(block)
            block = []
    if block:
        yield from check(block)


# ============================================================================
# Prose markup -- line and inline heuristics
# ============================================================================
#
# These are pattern heuristics, not parsers, so they assume the document follows
# the house conventions: one source line per paragraph, and literals in
# backticks. Under those conventions they are reliable enough to gate as errors.
# They are not safe on hard-wrapped prose or on an unquoted literal `*`.
#
# one-sentence-per-line (§one-sentence-per-line): two or more consecutive prose
# lines that each end a sentence are the signature of newline-per-sentence
# source. A paragraph written as one source line ends in terminal punctuation
# once, so it never forms such a run.
#
# inline-formatting-semantics (§inline-formatting-semantics): bold appears only
# in headings and paragraph headers; emphasis in body text is italic. A
# standalone `*Header*` line (a paragraph header) is excluded, and a leading
# `* item` list marker is blanked so it is not read as bold - but bold inside
# the item's own text is still flagged.

# A paragraph header (§paragraph-headers) is a bold phrase standing as a whole
# list item, optionally behind a list marker and an anchor: `. *Security*`,
# `.. [[id]]*Live metrics*`. Bold is licensed there when the header has no
# terminal period. Bold appearing mid-sentence remains prohibited.
PARAGRAPH_HEADER_RE = re.compile(
    r"^(?:[.*]+\s+)?(?:\[\[[^\]]*\]\]|\[#[^\]]*\])?\s*"
    r"\*{1,2}(?P<header>[^*]+)\*{1,2}\s*$")
PARAGRAPH_HEADER_MINOR_WORDS = frozenset({
    "a", "an", "and", "as", "at", "but", "by", "for", "from", "in",
    "into", "nor", "of", "on", "or", "per", "the", "to", "via", "with",
    "without",
})
PARAGRAPH_HEADER_WORD_RE = re.compile(r"[A-Za-z][A-Za-z'-]*")
# Bold comes in two forms: constrained `*word*` (rejects a doubled `*` at either
# edge) and unconstrained `**word**`. Both are banned in body text; the second
# regex catches the double-asterisk form the first deliberately skips.
BOLD_IN_BODY_RE = re.compile(r"(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])")
BOLD_UNCONSTRAINED_RE = re.compile(r"\*\*(?=\S).+?\*\*")


def _paragraph_header_uses_title_case(header: str) -> bool:
    """Return true when ordinary header words follow title capitalization."""
    words = PARAGRAPH_HEADER_WORD_RE.findall(_mask_code(header))
    ordinary: List[str] = []
    for word in words:
        if word.lower() in PARAGRAPH_HEADER_MINOR_WORDS:
            continue
        if word.isupper() or any(char.isupper() for char in word[1:]):
            # Acronyms, identifiers, and internal capitals do not establish case.
            continue
        ordinary.append(word)
    title_words = [word for word in ordinary if word[0].isupper()]
    lower_words = [word for word in ordinary if word[0].islower()]
    return len(title_words) >= 2 and not lower_words


def _is_sentence_line(text: str) -> bool:
    s = text.strip()
    if not s or s[0] in ".=*#-|/+:[":
        return False
    if s.startswith(("image:", "//")):
        return False
    return s[-1] in ".?!"


def rule_one_sentence_per_line(doc: Document) -> Iterator[Finding]:
    run_start = None
    run_len = 0
    for line in doc.lines:
        if line.block == "none" and not line.in_table \
                and _is_sentence_line(line.text):
            if run_start is None:
                run_start = line.num
            run_len += 1
        else:
            if run_len >= 2:
                yield (run_start, 1,
                       "Consecutive lines each end a sentence, so write the "
                       "paragraph as continuous prose (§one-sentence-per-line)")
            run_start, run_len = None, 0
    if run_len >= 2:
        yield (run_start, 1,
               "Consecutive lines each end a sentence, so write the paragraph as "
               "continuous prose (§one-sentence-per-line)")


def rule_bold_in_body(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        if line.in_table:
            continue
        stripped = line.text.strip()
        paragraph_header = PARAGRAPH_HEADER_RE.match(stripped)
        if paragraph_header:
            header = paragraph_header.group("header").rstrip()
            if header.endswith("."):
                yield (line.num, len(line.text.rstrip()),
                       "Bold paragraph header must not end with a period")
            if _paragraph_header_uses_title_case(header):
                yield (line.num, line.text.find(header) + 1,
                       "Bold paragraph header must use sentence case, not "
                       "title case")
            continue
        # An unordered-list marker's `*`/`**` is not bold, but the item's content
        # can still carry inline bold. Blank the marker (preserving columns) and
        # check the rest, rather than skipping the whole line.
        text = line.text
        marker = UNORDERED_MARKER_RE.match(text)
        if marker:
            end = marker.end(1)
            text = " " * end + text[end:]
        # Mask inline code spans and `++...++` passthroughs so a literal `*`/`**`
        # inside them is not read as an emphasis delimiter.
        masked = PASSTHROUGH_INNER_RE.sub(
            lambda m: " " * len(m.group(0)), _mask_code(text))
        seen: set[int] = set()
        for pattern in (BOLD_UNCONSTRAINED_RE, BOLD_IN_BODY_RE):
            for m in pattern.finditer(masked):
                if m.start() in seen:
                    continue
                seen.add(m.start())
                yield (line.num, m.start() + 1,
                       "Bold in body text where a word carrying emphasis should "
                       "be italic (§inline-formatting-semantics)")


# A constrained italic span cannot safely contain a monospaced span. The
# AsciiDoc-to-DocBook-to-DOCX path flattens the nested formatting and can emit
# the backticks as curly quote marks while italicizing the technical literal.
# Keep the two roles adjacent instead: `` `example.org` _application layer_ ``.
# This is a source-level integrity rule because Asciidoctor accepts the broken
# nesting without a warning. Literal examples inside verbatim blocks are
# excluded by `_prose`.
ITALIC_WITH_CODE_RE = re.compile(
    r"(?<![\w_])_(?!_)(?P<body>[^_\n]*`+[^`\n]+`+[^_\n]*)_(?![\w_])")
UNCONSTRAINED_ITALIC_WITH_CODE_RE = re.compile(
    r"__(?=\S)(?P<body>[^\n]*?`+[^`\n]+`+[^\n]*?)__")


def rule_code_in_italics(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        seen: set[int] = set()
        for pattern in (UNCONSTRAINED_ITALIC_WITH_CODE_RE,
                        ITALIC_WITH_CODE_RE):
            for match in pattern.finditer(line.text):
                code = CODE_SPAN_RE.search(match.group("body"))
                if code is None:
                    continue
                column = match.start("body") + code.start() + 1
                if column in seen:
                    continue
                seen.add(column)
                yield (line.num, column,
                       "Code span nested inside italics renders incorrectly in "
                       "DOCX; close the italics before the code span and reopen "
                       "them after it")


# A render-integrity check. A constrained monospace span (`` `text` ``) still
# runs inline substitutions on its content, so a word-boundary `*` inside it is
# parsed as a bold delimiter. Two facts, both verified empirically (Asciidoctor
# exits 0 with no warning either way), define the exact defect:
#
#   * Only a BOLDING asterisk counts. A `*` wedged between two word characters
#     (`` `co*de` ``, `` `2*3` ``) is never an emphasis delimiter and never
#     leaks; a `*` touching a boundary (span edge, space, `-`, `.`, `/`, ...) is.
#   * Only an ODD number of bolding asterisks is the bug. An even number closes
#     its own pairs inside the span -- deliberate bold like `` `pre-*x*-post` ``
#     is allowed. An odd number leaves a dangling delimiter. Alone it renders
#     literal, but it is NON-LOCAL: the moment another span carries a dangling
#     delimiter the two pair into a bold run that swallows the text between them
#     AND breaks both spans (their backticks render as literal text).
#
# So this rule flags a code span holding an odd count of bolding asterisks. The
# robust fix is a passthrough -- `` `++*++` `` for the character, or a whole-span
# `` `+...+` `` -- the form the guideline itself uses (`` `++*++` ``/`` `++**++` ``),
# which is why those never trip. Asterisks inside a `++...++` passthrough, behind a
# `\*` escape, or in a whole-span `+...+` passthrough are not counted. Runs on
# prose lines only; a `*` inside a `[source]` listing or `....` block is literal
# source and never reaches here.

PASSTHROUGH_INNER_RE = re.compile(r"\+\+.*?\+\+")


def _bolding_asterisk_count(inner: str) -> int:
    """Number of emphasis-eligible `*` in a code span's inner text: raw `*`
    touching a non-word boundary on at least one side, excluding those inside a
    `++...++` passthrough or behind a `\\*` escape."""
    escaped = set()
    for m in PASSTHROUGH_INNER_RE.finditer(inner):
        escaped.update(range(m.start(), m.end()))
    count = 0
    for k, ch in enumerate(inner):
        if ch != "*" or k in escaped or (k > 0 and inner[k - 1] == "\\"):
            continue
        before = inner[k - 1] if k > 0 else None
        after = inner[k + 1] if k + 1 < len(inner) else None
        if not ((before is not None and before.isalnum())
                and (after is not None and after.isalnum())):
            count += 1
    return count


def rule_asterisk_in_code(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for m in CODE_SPAN_RE.finditer(line.text):
            inner = m.group(0).strip("`")
            if len(inner) >= 2 and inner.startswith("+") and inner.endswith("+"):
                continue  # a whole-span `+...+` passthrough: contents are literal
            if _bolding_asterisk_count(inner) % 2 == 1:
                yield (line.num, m.start() + 1,
                       "Code span has an odd, unbalanced bolding `*` that "
                       "renders as bold and can bleed across the line, breaking "
                       "this span and others; balance it or write the literal "
                       "`*` as a passthrough, e.g. `++*++`")


# A constrained monospace span still applies inline substitutions. If its
# entire content is a run of three or more plus signs, Asciidoctor consumes
# paired signs as formatting delimiters without warning. Even-length runs emit
# an empty `<code>` element, while odd-length runs emit only one plus sign.
# `pass:[...]` makes the intended literal explicit while preserving monospace.
def rule_plus_delimiter_in_code(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for match in CODE_SPAN_RE.finditer(line.text):
            inner = match.group(0).strip("`")
            if re.fullmatch(r"\+{3,}", inner):
                yield (line.num, match.start() + 1,
                       "Code span containing three or more plus signs loses "
                       "content when rendered; wrap the signs in `pass:[]` "
                       "inside the span")


# ============================================================================
# Paragraph and section size -- sentence caps, body caps, opener monotony
# ============================================================================
#
# These rules exploit the one-line-per-paragraph convention: a paragraph IS a
# source line, so paragraph-level counting is exact. Sentence boundaries are
# terminal punctuation followed by whitespace, after masking code spans,
# resolving xref/link macros to their text, and dropping common abbreviations
# (e.g., i.e., etc.) that would inflate the count.
#
# one-paragraph-one-topic (§one-paragraph-one-topic): a paragraph develops one
# topic. Topic drift isn't mechanically checkable, but its gross signature is:
# a paragraph holding more sentences than one topic plausibly needs.
#
# section-body-length (§section-nesting): the dual of `lone-subsection` --
# that rule catches over-splitting, this catches under-splitting. The body is
# the prose between a heading and the next heading of any level; a body over
# the cap needs subsections.
#
# sentence-opener-runs: a long run of consecutive sentences opening with the
# same word is monotony, not parallelism. The threshold leaves room for a
# short deliberate parallel enumeration.

ABBREV_RE = re.compile(r"\b(?:e\.g|i\.e|etc|vs|cf)\.", re.IGNORECASE)
SENTENCE_END_RE = re.compile(r"[.!?]+[\"')\]]*(?:\s+|$)")
PROSE_WORD_RE = re.compile(r"[^\W\d_]+")
XREF_TEXT_RE = re.compile(r"xref:[^\[\]\s]*\[([^\]]*)\]")
BLOCK_ANCHOR_FULL_RE = re.compile(r"\[\[\[?[^\]]*\]\]\]?")
# A footnote is an aside attached to a word, not part of the sentence that
# carries it. Its text must not inflate the sentence-length, paragraph, and
# section-body word counts, and its markup must not glue the two prose
# sentences it sits between. Dropping the whole `footnote:id[...]` macro (named
# or anonymous) before those rules run restores the sentence boundary the
# attaching period marks. The `\\.` alternative steps over escaped characters,
# so a citation quote's `\]` doesn't truncate the match mid-macro.
FOOTNOTE_RE = re.compile(r"footnote:[\w-]*\[(?:\\.|[^\[\]]|\[[^\[\]]*\])*\]")

MAX_SENTENCES_PER_PARAGRAPH = 8
MAX_SECTION_BODY_WORDS = 600
MAX_OPENER_RUN = 4


def _rendered(text: str) -> str:
    """Approximate the rendered prose of a source line: code spans masked,
    macros replaced by their display text, anchors dropped."""
    t = _mask_code(text)
    t = FOOTNOTE_RE.sub(" ", t)
    t = XREF_TEXT_RE.sub(r"\1", t)
    t = LINK_RE.sub(r"\1", t)
    t = BLOCK_ANCHOR_FULL_RE.sub(" ", t)
    return t


def _paragraphs(doc: Document) -> Iterator[Line]:
    """Prose content lines: paragraphs and list items, without headings,
    block titles, metadata, tables, or macros standing alone. Bibliography
    entries are records, not prose, so the sentence and vocabulary rules
    (and the diagnostics totals) skip the bibliography section."""
    ana = source_analysis(doc)
    for line in doc.lines:
        if line.block != "none" or line.in_table:
            continue
        if _in_bib(ana, line.num):
            continue
        s = line.text.strip()
        if not s or HEADING_RE.match(line.text):
            continue
        if s[0] in "=[:|/<+" or s.startswith("image:"):
            continue
        if s[0] == "." and not ORDERED_MARKER_RE.match(s):
            continue
        yield line


def _sentence_source(text: str) -> str:
    return ABBREV_RE.sub(" ", _rendered(text))


# ==========================================================================
# Scope-stable prose punctuation
# ==========================================================================
#
# Vale assigns direct list-item and inline-admonition text to `list` and
# `text` scopes rather than `sentence`/`paragraph`. Sentence-scoped styles
# therefore miss those contexts. A citation footnote containing its own
# semicolon can also consume the Semicolons style's match for the sentence and
# hide a later author-prose semicolon. These checks run on the source tree
# instead. They cover body paragraphs, list items, admonitions, description
# items, and table cells through one shared iterator.
#
# The mask is length-preserving: citation footnotes, inline literals, anchors,
# and macro targets disappear without moving a finding's source column. Macro
# display text remains visible because it is author prose. Existing Vale
# `NO`/`YES` directives still suppress the deliberately bad examples in the
# writing guideline.

VALE_TOGGLE_RE = re.compile(
    r"<!--\s*vale\s+([\w.]+)\s*=\s*(NO|YES)\s*-->", re.IGNORECASE)
PROSE_PREFIX_RE = re.compile(
    r"^\s*(?:(?:\.+|\*+)\s+|(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION):\s+|"
    r"[^:\n]+::\s+)")
TABLE_SEPARATOR_RE = re.compile(r"(?<!\\)\|")


def _disabled_lines(doc: Document, check: str) -> set[int]:
    disabled: set[int] = set()
    enabled = True
    for line in doc.lines:
        for match in VALE_TOGGLE_RE.finditer(line.text):
            if match.group(1).lower() == check.lower():
                enabled = match.group(2).upper() == "YES"
        if not enabled:
            disabled.add(line.num)
    return disabled


def _table_cells(doc: Document) -> Iterator[Tuple[str, int, int]]:
    """Yield (cell text, source line, 1-based source column).

    An escaped `\\|` stays in its cell. An unescaped `|` is an AsciiDoc table
    separator even inside inline formatting, so source offsets remain exact.
    """
    ana = source_analysis(doc)
    for line in doc.lines:
        if not line.in_table or line.block != "none" \
                or _in_bib(ana, line.num):
            continue
        stripped = line.text.strip()
        if not stripped.startswith("|") or set(stripped) <= set("|="):
            continue
        separators = list(TABLE_SEPARATOR_RE.finditer(line.text))
        for index, separator in enumerate(separators):
            start = separator.end()
            end = (separators[index + 1].start()
                   if index + 1 < len(separators) else len(line.text))
            piece = line.text[start:end]
            cell = piece.strip()
            if not cell:
                continue
            lead = len(piece) - len(piece.lstrip())
            yield cell, line.num, start + lead + 1


def _author_units(doc: Document) -> Iterator[Tuple[str, int, int]]:
    """Yield author-prose units with exact source origins."""
    ana = source_analysis(doc)
    citation_spans: Dict[int, List[Tuple[int, int]]] = {}
    for citation in ana.citations:
        citation_spans.setdefault(citation.line, []).append(
            (citation.start_col, citation.end_col))

    def with_notes(text: str, line_num: int, source_col: int):
        yield text, line_num, source_col
        for footnote in FOOTNOTE_RE.finditer(text):
            macro_col = source_col + footnote.start()
            if any(start <= macro_col < end
                   for start, end in citation_spans.get(line_num, ())):
                continue
            macro = footnote.group(0)
            body_start = macro.find("[") + 1
            body = macro[body_start:-1]
            if body:
                yield (body, line_num,
                       source_col + footnote.start() + body_start)

    for line in _paragraphs(doc):
        match = PROSE_PREFIX_RE.match(line.text)
        start = match.end() if match else 0
        yield from with_notes(line.text[start:], line.num, start + 1)
    for text, line_num, source_col in _table_cells(doc):
        yield from with_notes(text, line_num, source_col)


def _retain_macro_text(match: re.Match) -> str:
    start, end = match.span(1)
    return (" " * start + match.group(1)
            + " " * (len(match.group(0)) - end))


def _author_mask(text: str) -> str:
    masked = _mask_code(text)
    masked = FOOTNOTE_RE.sub(lambda m: " " * len(m.group(0)), masked)
    masked = XREF_TEXT_RE.sub(_retain_macro_text, masked)
    masked = LINK_RE.sub(_retain_macro_text, masked)
    return BLOCK_ANCHOR_FULL_RE.sub(
        lambda m: " " * len(m.group(0)), masked)


def rule_semicolons(doc: Document) -> Iterator[Finding]:
    disabled = _disabled_lines(doc, "English.Semicolons")
    for text, line_num, source_col in _author_units(doc):
        if line_num in disabled:
            continue
        for match in re.finditer(r";", _author_mask(text)):
            yield (line_num, source_col + match.start(),
                   "A semicolon joins separate thoughts; consider "
                   "splitting them into separate sentences")


COLON_CAP_RE = re.compile(r"(?<!:):\s+([A-Z][\w.]*)")
COLON_PROPER_WORDS = frozenset({
    "Payload", "Flutter", "Microsoft", "Storybook", "Amazon", "Google",
    "Azure", "Braze", "Cloudinary", "CloudFront", "Redshift", "BigQuery",
    "Deloitte", "PwC", "KPMG", "EY", "Claude", "Kanban", "Scrum", "DataRide",
    "WordPress", "ProCyclingStats",
})


def _proper_after_colon(word: str) -> bool:
    return (word in COLON_PROPER_WORDS
            or (word.isupper() and len(word) > 1)
            or bool(re.search(r"[a-z][A-Z]", word))
            or bool(re.fullmatch(r"[A-Z][a-z]+\.[a-z]+", word)))


def rule_colon_case(doc: Document) -> Iterator[Finding]:
    disabled = _disabled_lines(doc, "English.Colons")
    for text, line_num, source_col in _author_units(doc):
        if line_num in disabled:
            continue
        for match in COLON_CAP_RE.finditer(_author_mask(text)):
            word = match.group(1)
            if _proper_after_colon(word):
                continue
            yield (line_num, source_col + match.start(1),
                   f"{word!r} should be lowercase after the colon")


# Deliberately conservative. The former Vale expression treated appositives
# and nested conjunctions as lists. This pattern gates the unambiguous case: a
# flat series of at least three single-word items whose final separator lacks
# the Oxford comma. More complex lists remain a prose-review responsibility.
SIMPLE_MISSING_OXFORD_RE = re.compile(
    r"\b[\w-]+(?:,\s+[\w-]+)+\s+(and|or)\s+[\w-]+\s*$",
    re.IGNORECASE)


def _sentence_slices(text: str) -> Iterator[Tuple[int, str]]:
    probe = ABBREV_RE.sub(lambda m: " " * len(m.group(0)), text)
    start = 0
    for boundary in SENTENCE_END_RE.finditer(probe):
        yield start, text[start:boundary.start()]
        start = boundary.end()
    if start < len(text):
        yield start, text[start:]


def rule_oxford_comma(doc: Document) -> Iterator[Finding]:
    disabled = _disabled_lines(doc, "English.OxfordComma")
    for text, line_num, source_col in _author_units(doc):
        if line_num in disabled:
            continue
        masked = _author_mask(text)
        for sentence_start, sentence in _sentence_slices(masked):
            match = SIMPLE_MISSING_OXFORD_RE.search(sentence.strip())
            if not match:
                continue
            relative = sentence.find(match.group(0)) + match.start(1)
            yield (line_num, source_col + sentence_start + relative,
                   "Use the Oxford comma before the final item in this "
                   "simple series")


def rule_paragraph_but(doc: Document) -> Iterator[Finding]:
    disabled = _disabled_lines(doc, "English.But")
    for text, line_num, source_col in _author_units(doc):
        if line_num in disabled:
            continue
        match = re.match(r"\s*But\b", _author_mask(text), re.IGNORECASE)
        if match:
            yield (line_num, source_col + match.start(),
                   "Do not start a paragraph or list item with 'But'")


def rule_paragraph_sentences(doc: Document) -> Iterator[Finding]:
    for line in _paragraphs(doc):
        n = len(SENTENCE_END_RE.findall(_sentence_source(line.text)))
        if n > MAX_SENTENCES_PER_PARAGRAPH:
            yield (line.num, 1,
                   f"Paragraph holds {n} sentences, exceeding the cap of "
                   f"{MAX_SENTENCES_PER_PARAGRAPH}; split it "
                   f"(§one-paragraph-one-topic)")


def _section_bodies(doc: Document) -> List[Tuple[int, int]]:
    """(heading_line, body_words) for every heading: the prose word count
    between the heading and the next heading of any level."""
    heading_nums = {num for num, _ in doc.headings}
    paragraph_nums = {ln.num for ln in _paragraphs(doc)}
    bodies: List[Tuple[int, int]] = []
    current, words = None, 0
    for line in doc.lines:
        if line.num in heading_nums:
            if current is not None:
                bodies.append((current, words))
            current, words = line.num, 0
        elif line.num in paragraph_nums:
            words += len(PROSE_WORD_RE.findall(_rendered(line.text)))
    if current is not None:
        bodies.append((current, words))
    return bodies


def rule_section_body_words(doc: Document) -> Iterator[Finding]:
    for heading_line, body_words in _section_bodies(doc):
        if body_words > MAX_SECTION_BODY_WORDS:
            yield (heading_line, 1,
                   f"Section body holds {body_words} words before the next "
                   f"heading, exceeding the cap of {MAX_SECTION_BODY_WORDS}; "
                   f"split it into subsections (§section-nesting)")


def _sentence_openers(text: str) -> List[str]:
    openers = []
    for part in SENTENCE_END_RE.split(_sentence_source(text)):
        if not part.strip():
            continue
        m = PROSE_WORD_RE.search(part)
        openers.append(m.group(0).lower() if m else "")
    return openers


def _max_opener_run(openers: List[str]) -> Tuple[int, str]:
    run = best = 1
    word = openers[0] if openers else ""
    for prev, cur in zip(openers, openers[1:]):
        run = run + 1 if cur and cur == prev else 1
        if run > best:
            best, word = run, cur
    return best, word


def rule_sentence_opener_runs(doc: Document) -> Iterator[Finding]:
    for line in _paragraphs(doc):
        run, word = _max_opener_run(_sentence_openers(line.text))
        if run > MAX_OPENER_RUN:
            yield (line.num, 1,
                   f"{run} consecutive sentences open with the word "
                   f"{word!r}; vary the sentence openers")


# sentence-length: one sentence stays under the word cap. Vale's own
# SentenceLength rule (scope `sentence`) cannot own this metric: its AsciiDoc
# path classifies the direct text of a list item as the `list` scope, so
# sentences written straight on a `. item` or `* item` line were never
# measured, and closing the gap with a second, Python-side rule left one
# threshold owned by two engines that count words slightly differently --
# a report the reader can't trust without knowing Vale's scope model. This
# rule therefore owns the metric alone, over every prose line `_paragraphs`
# yields, and the Vale rule is deleted. Word counting reuses the shared
# sentence pipeline (code spans and italics masked, macros rendered), so the
# `longest sentence` diagnostics row and this rule can never disagree.

MAX_SENTENCE_WORDS = 45


def rule_sentence_length(doc: Document) -> Iterator[Finding]:
    for line in _paragraphs(doc):
        source = ITALIC_SPAN_RE.sub(" ", _sentence_source(line.text))
        for part in SENTENCE_END_RE.split(source):
            n = len(PROSE_WORD_RE.findall(part))
            if n > MAX_SENTENCE_WORDS:
                yield (line.num, 1,
                       f"Sentence runs {n} words, exceeding the cap of "
                       f"{MAX_SENTENCE_WORDS}. Split it: one sentence, "
                       f"one thought.")


# ============================================================================
# Abstractness -- graded-lexicon vocabulary check (English)
# ============================================================================
#
# Serves concrete-vocabulary (§concrete-vocabulary): prose stays anchored in
# things the reader can picture. Each English word carries an abstractness
# grade (0 fully concrete .. 100 fully abstract) taken from the human-rated
# concreteness norms of Brysbaert, Warriner & Kuperman (2014), shipped as
# `abstractness_en.tsv` next to this file. `abstractness_extra_en.tsv`, when
# present, adds or overrides grades for curated project vocabulary in the
# same format. A sentence is flagged when the MEAN grade of its graded
# content words crosses the cap -- abstraction stacked on abstraction with no
# concrete anchor.
#
# Three deliberate scoring policies keep the check fail-safe:
#   - Ungraded words (domain terms, product names, coinages) are omitted, not
#     guessed, so correct technical jargon never pushes a sentence over the
#     cap. The suffix-based nominalization-density rule below is the
#     open-world backstop for vocabulary this closed lexicon misses.
#   - Function words are excluded via the stopword set below: the norms grade
#     them (e.g. "the" rates highly abstract), and including them would let
#     syntax swamp the vocabulary signal the rule exists to measure.
#   - Italic spans are masked before scoring. Per inline-formatting-semantics
#     (§inline-formatting-semantics), italics mark terms of art and words
#     mentioned as words -- vocabulary the sentence names rather than uses,
#     which shouldn't count as the author's own word choice.
#   - Sentences with fewer graded words than the coverage floor are skipped
#     as statistically meaningless.
# English-only: `.pl.adoc` files are excluded.

ABSTRACTNESS_LEXICON_FILE = "abstractness_en.tsv"
ABSTRACTNESS_EXTRA_FILE = "abstractness_extra_en.tsv"
MAX_MEAN_ABSTRACTNESS = 70
MIN_GRADED_WORDS = 5

STOPWORDS = frozenset("""
the a an this that these those such same own other another each every either
neither both all any some few many much more most several no only
i you he she it we they me him her us them my your his its our their mine
yours hers ours theirs myself yourself himself herself itself ourselves
yourselves themselves who whom whose which what
am is are was were be been being do does did done have has had having
will would shall should can could may might must ought
of in on at by for with about against between into through during before
after above below to from up down out off over under again further
and but or nor so yet if then else when while where why how because although
though unless until as than too very just also not once here there
""".split())

_abstractness_cache: Dict[str, int] = {}
_abstractness_loaded = False


def _abstractness_lexicon() -> Dict[str, int]:
    global _abstractness_loaded
    if _abstractness_loaded:
        return _abstractness_cache
    lib_dir = os.path.dirname(os.path.abspath(__file__))
    base = os.path.join(lib_dir, ABSTRACTNESS_LEXICON_FILE)
    if not os.path.exists(base):
        sys.stderr.write(
            f"adoc_lint: {ABSTRACTNESS_LEXICON_FILE} is required next to "
            "adoc_lint.py but was not found.\n")
        sys.exit(2)
    for path in (base, os.path.join(lib_dir, ABSTRACTNESS_EXTRA_FILE)):
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            for raw in f:
                raw = raw.strip()
                if not raw or raw.startswith("#"):
                    continue
                word, _, grade = raw.partition("\t")
                if grade.strip().isdigit():
                    _abstractness_cache[word.strip().lower()] = int(grade)
    _abstractness_loaded = True
    return _abstractness_cache


def _abstractness_of(word: str, lexicon: Dict[str, int]):
    """Grade of a word, matching the surface form first and then the
    deterministic singular fallbacks (-ies -> -y, -es, -s)."""
    if word in lexicon:
        return lexicon[word]
    if word.endswith("ies") and word[:-3] + "y" in lexicon:
        return lexicon[word[:-3] + "y"]
    for suffix in ("es", "s"):
        if word.endswith(suffix) and word[:-len(suffix)] in lexicon:
            return lexicon[word[:-len(suffix)]]
    return None


ITALIC_SPAN_RE = re.compile(r"(?<!\w)_([^_\n]+)_(?!\w)")


def _sentence_abstractness(part: str,
                           lexicon: Dict[str, int]) -> Tuple[float, int]:
    """Mean abstractness of a sentence's graded content words and their
    count. Returns (0.0, 0) when nothing is graded."""
    grades = []
    for token in PROSE_WORD_RE.findall(part):
        word = token.lower()
        if word in STOPWORDS:
            continue
        grade = _abstractness_of(word, lexicon)
        if grade is not None:
            grades.append(grade)
    if not grades:
        return (0.0, 0)
    return (sum(grades) / len(grades), len(grades))


def rule_abstract_vocabulary(doc: Document) -> Iterator[Finding]:
    if doc.path.endswith(".pl.adoc"):
        return
    lexicon = _abstractness_lexicon()
    for line in _paragraphs(doc):
        source = ITALIC_SPAN_RE.sub(" ", _sentence_source(line.text))
        for part in SENTENCE_END_RE.split(source):
            mean, count = _sentence_abstractness(part, lexicon)
            if count < MIN_GRADED_WORDS:
                continue
            if mean > MAX_MEAN_ABSTRACTNESS:
                yield (line.num, 1,
                       f"Sentence averages {mean:.0f}/100 abstractness over "
                       f"{count} graded words, exceeding the cap of "
                       f"{MAX_MEAN_ABSTRACTNESS}; anchor it in concrete "
                       f"terms (§concrete-vocabulary)")


# ============================================================================
# Nominalization density -- direct verbs over stacked abstract nouns
# ============================================================================
#
# Serves direct-verbs (§direct-verbs): one sentence doesn't bury its actions
# under a pile of abstract nouns. Every extra -tion/-ment/-ity noun is an
# action or quality nominalized instead of stated as a verb, and a sentence
# that stacks too many of them reads as fog. Where the graded-lexicon
# concrete-vocabulary check above is closed-world -- it scores only words it
# has a grade for -- this open-world suffix count is its backstop: it needs no
# lexicon entry to catch an unfamiliar nominalization.
#
# This owned Vale's `English.Nominalizations` (`scope: sentence`), but Vale's
# AsciiDoc position mapping drifts across accumulated block elements, so in a
# structurally dense document it reported the sentence tens or hundreds of
# lines from where it actually sits. Re-homing the metric onto the shared
# sentence pipeline (`_paragraphs` + `_sentence_source`: code spans and
# footnotes masked, macros rendered to their display text) makes the reported
# line exact and keeps the count consistent with the other sentence rules. The
# Vale rule is deleted; like the other re-homed sentence rules it measures
# every prose line `_paragraphs` yields, not `|===` cells.

NOMINALIZATION_RE = re.compile(
    r"\b[A-Za-z]+(?:tions?|sions?|ments?|ances?|ences?|ities|ity|ness(?:es)?)\b")
MAX_NOMINALIZATIONS = 7


def rule_nominalization_density(doc: Document) -> Iterator[Finding]:
    for line in _paragraphs(doc):
        for part in SENTENCE_END_RE.split(_sentence_source(line.text)):
            n = len(NOMINALIZATION_RE.findall(part))
            if n > MAX_NOMINALIZATIONS:
                yield (line.num, 1,
                       f"Sentence stacks {n} abstract nominalizations "
                       f"(-tion, -ment, -ity, ...), exceeding the cap of "
                       f"{MAX_NOMINALIZATIONS}; prefer direct verbs and "
                       f"concrete nouns (§direct-verbs)")


# ============================================================================
# Diagnostics -- per-file metrics panel
# ============================================================================
#
# The text report shows, for every linted file, the measured value behind
# each threshold-backed structural check: the threshold, the observed
# extreme, its location, and for the abstractness check the constituent
# words with their grades. A passing run thereby shows how much headroom
# each metric has left instead of a bare green summary. Metrics enforced by
# Vale (LIX, average paragraph length, heading length) are
# recomputed here approximately for orientation and prefixed "~"; their caps
# are read from the .vale/styles files at runtime rather than restated here,
# so the .yml files stay the single source of truth.

_VALE_CAP_CACHE: Dict[str, str] = {}
_VALE_CAP_RE = re.compile(
    r'^(?:condition:\s*"?[><]=?\s*|max:\s*)(\d+(?:\.\d+)?)\s*"?\s*$',
    re.MULTILINE)


def _vale_cap(style_rel_path: str) -> str:
    """The threshold a Vale style file declares (its `max:` or numeric
    `condition:` line), read from disk so the .yml stays authoritative.
    Empty string when the file or the threshold can't be found."""
    if style_rel_path in _VALE_CAP_CACHE:
        return _VALE_CAP_CACHE[style_rel_path]
    styles_dir = ".vale/styles"
    ini = os.path.join(os.getcwd(), ".vale.ini")
    if os.path.exists(ini):
        with open(ini, encoding="utf-8") as f:
            m = re.search(r"^StylesPath\s*=\s*(\S+)", f.read(), re.MULTILINE)
        if m:
            styles_dir = m.group(1)
    cap = ""
    path = os.path.join(os.getcwd(), styles_dir, style_rel_path)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            m = _VALE_CAP_RE.search(f.read())
        if m:
            cap = m.group(1)
    _VALE_CAP_CACHE[style_rel_path] = cap
    return cap


def _capped(style_rel_path: str, text: str) -> str:
    cap = _vale_cap(style_rel_path)
    return f"cap {cap} · {text}" if cap else text

def _top_abstract_words(part: str, lexicon: Dict[str, int],
                        k: int = 5) -> str:
    graded = []
    for token in PROSE_WORD_RE.findall(part):
        word = token.lower()
        if word in STOPWORDS:
            continue
        grade = _abstractness_of(word, lexicon)
        if grade is not None:
            graded.append((grade, word))
    graded.sort(reverse=True)
    return " ".join(f"{w}={g}" for g, w in graded[:k])


def file_diagnostics(doc: Document) -> List[Tuple[str, str]]:
    paragraphs = list(_paragraphs(doc))
    total_words = total_sentences = total_long = 0
    max_sentence = (0, 0)        # (words, line)
    max_paragraph = (0, 0)       # (sentences, line)
    max_run = (1, "", 0)         # (run, word, line)
    max_abstract = (0.0, 0, 0, "")  # (mean, graded words, line, sentence)
    max_nominal = (0, 0)         # (count, line)
    is_english = not doc.path.endswith(".pl.adoc")
    lexicon = _abstractness_lexicon() if is_english else {}

    for line in paragraphs:
        source = _sentence_source(line.text)
        tokens = PROSE_WORD_RE.findall(source)
        total_words += len(tokens)
        total_long += sum(1 for t in tokens if len(t) > 6)
        n_sentences = len(SENTENCE_END_RE.findall(source))
        total_sentences += n_sentences
        if n_sentences > max_paragraph[0]:
            max_paragraph = (n_sentences, line.num)
        run, word = _max_opener_run(_sentence_openers(line.text))
        if run > max_run[0]:
            max_run = (run, word, line.num)
        italic_masked = ITALIC_SPAN_RE.sub(" ", source)
        for part in SENTENCE_END_RE.split(italic_masked):
            n_part_words = len(PROSE_WORD_RE.findall(part))
            if n_part_words > max_sentence[0]:
                max_sentence = (n_part_words, line.num)
            if is_english:
                mean, count = _sentence_abstractness(part, lexicon)
                if count >= MIN_GRADED_WORDS and mean > max_abstract[0]:
                    max_abstract = (mean, count, line.num, part)
        for part in SENTENCE_END_RE.split(source):
            n_nom = len(NOMINALIZATION_RE.findall(part))
            if n_nom > max_nominal[0]:
                max_nominal = (n_nom, line.num)

    max_heading = (0, 0)
    for num, _level in doc.headings:
        text = doc.lines[num - 1].text.lstrip("=").strip()
        n = len(PROSE_WORD_RE.findall(_rendered(text)))
        if n > max_heading[0]:
            max_heading = (n, num)
    max_body = max(_section_bodies(doc), key=lambda b: b[1],
                   default=(0, 0))

    rows: List[Tuple[str, str]] = [
        ("prose", f"{total_words} words · {total_sentences} sentences · "
                  f"{len(paragraphs)} paragraphs · "
                  f"{len(doc.headings)} headings"),
    ]
    lix_style = "English/LIX.yml" if is_english else "Polish/LIX.yml"
    if total_words and total_sentences:
        asl = total_words / total_sentences
        plw = 100 * total_long / total_words
        rows.append(("~lix", _capped(
            lix_style,
            f"{asl + plw:.1f} = {asl:.1f} words/sentence "
            f"+ {plw:.1f}% long words")))
    if paragraphs:
        rows.append(("~words/paragraph", _capped(
            "LanguageNeutral/AvgParagraphLength.yml",
            f"{total_words / len(paragraphs):.1f} average")))
    rows.append(("longest sentence",
                 f"cap {MAX_SENTENCE_WORDS} · {max_sentence[0]} words "
                 f"(line {max_sentence[1]})"))
    rows.append(("~longest heading", _capped(
        "LanguageNeutral/HeadingLength.yml",
        f"{max_heading[0]} words (line {max_heading[1]})")))
    rows.append(("section body",
                 f"cap {MAX_SECTION_BODY_WORDS} · max {max_body[1]} words "
                 f"(line {max_body[0]})"))
    rows.append(("sentences/paragraph",
                 f"cap {MAX_SENTENCES_PER_PARAGRAPH} · max "
                 f"{max_paragraph[0]} (line {max_paragraph[1]})"))
    if max_run[0] > 1:
        rows.append(("same-opener sentences",
                     f"cap {MAX_OPENER_RUN} · max {max_run[0]} consecutive "
                     f"sentences open with {max_run[1]!r} "
                     f"(line {max_run[2]})"))
    else:
        rows.append(("same-opener sentences",
                     f"cap {MAX_OPENER_RUN} · no two consecutive sentences "
                     f"open with the same word"))
    rows.append(("nominalizations",
                 f"cap {MAX_NOMINALIZATIONS} · max {max_nominal[0]} "
                 f"(line {max_nominal[1]})"))
    if is_english and max_abstract[1]:
        mean, count, line_num, part = max_abstract
        rows.append(("abstractness",
                     f"cap {MAX_MEAN_ABSTRACTNESS} · max {mean:.1f} over "
                     f"{count} graded words (line {line_num}): "
                     f"{_top_abstract_words(part, lexicon)}"))
    elif not is_english:
        rows.append(("abstractness", "skipped (Polish document)"))
    ana = source_analysis(doc)
    if ana.bib_attr_line or ana.citations:
        n_defs = sum(1 for c in ana.citations if not c.is_reuse)
        n_reuses = sum(1 for c in ana.citations if c.is_reuse)
        _quote_results(doc)
        stats = ana.quote_stats or {}
        rows.append(("sources",
                     f"{len(ana.entries)} bibliography entries · "
                     f"{n_defs} citations · {n_reuses} reuses · "
                     f"{stats.get('verified', 0)}/{stats.get('checked', 0)}"
                     f" quotes verified · git mode {_doc_mode(doc)}"))
        if stats.get("ocr_checked"):
            rows.append(("tesseract",
                         f"{stats['ocr_verified']}/{stats['ocr_checked']} "
                         f"image quotes found in OCR text"))
    return rows


# ============================================================================
# Rule registry
# ============================================================================
#
# Each Rule binds a guideline-anchor id to a default severity and the function
# that finds it. `error` gates the exit code; `suggestion` never does. A
# project tunes a rule by editing its `enabled` or `severity` field here.

@dataclass
class Rule:
    id: str
    severity: str        # 'error' | 'warning' | 'suggestion'
    func: RuleFunc
    enabled: bool = True


RULES: List[Rule] = [
    Rule("section-nesting", "error", rule_heading_depth),
    Rule("lone-subsection", "error", rule_lone_subsection),
    Rule("numbering-depth", "error", rule_numbering_depth),
    Rule("orphan-continuation", "error", rule_orphan_continuation),
    Rule("glued-list-item", "error", rule_glued_list_item),
    Rule("continuation-content", "error", rule_continuation_content),
    Rule("single-item-list", "error", rule_single_item_list),
    Rule("alt-text", "error", rule_image_alt_text),
    Rule("link-text", "error", rule_link_text),
    Rule("explicit-anchors", "error", rule_auto_anchor),
    Rule("anchor-format", "error", rule_anchor_format),
    Rule("diagram-tabs", "error", rule_diagram_tabs),
    Rule("diagram-trailing-space", "error", rule_diagram_trailing_space),
    Rule("verbatim-flush-left", "error", rule_verbatim_flush_left),
    Rule("diagram-charset", "error", rule_diagram_charset),
    Rule("diagram-box-alignment", "error", rule_diagram_box_alignment),
    Rule("diagram-corner-support", "error", rule_diagram_corner_support),
    Rule("diagram-junction-support", "error", rule_diagram_junction_support),
    Rule("diagram-lifeline-alignment", "error", rule_diagram_lifeline_alignment),
    Rule("one-sentence-per-line", "error", rule_one_sentence_per_line),
    Rule("inline-formatting", "error", rule_bold_in_body),
    Rule("code-in-italics", "error", rule_code_in_italics),
    Rule("asterisk-in-code", "error", rule_asterisk_in_code),
    Rule("plus-delimiter-in-code", "error", rule_plus_delimiter_in_code),
    Rule("semicolons", "error", rule_semicolons),
    Rule("colon-case", "error", rule_colon_case),
    Rule("oxford-comma", "error", rule_oxford_comma),
    Rule("paragraph-but", "error", rule_paragraph_but),
    Rule("xref-targets", "error", rule_xref_targets),
    Rule("no-section-heading-self-references", "error",
         rule_no_section_heading_self_references),
    Rule("footnote-bare-bracket", "error", rule_footnote_bare_bracket),
    Rule("internal-references-with-xref", "error", rule_bare_id_xref),
    Rule("one-paragraph-one-topic", "error", rule_paragraph_sentences),
    Rule("section-body-length", "error", rule_section_body_words),
    Rule("sentence-opener-runs", "error", rule_sentence_opener_runs),
    Rule("sentence-length", "error", rule_sentence_length),
    Rule("concrete-vocabulary", "error", rule_abstract_vocabulary),
    Rule("nominalization-density", "error", rule_nominalization_density),
    Rule("split-code-dlist", "error", rule_split_code_dlist),
    Rule("anchor-in-code-span", "error", rule_anchor_in_code_span),
    Rule("footnote-boundary", "error", rule_footnote_after_code_span),
    Rule("autolink-boundary", "error", rule_autolink_after_code_span),
    Rule("footnote-punctuation", "error", rule_footnote_dot),
    Rule("citation-footnote-format", "error", rule_citation_footnote_format),
    Rule("bibliography-format", "error", rule_bibliography_format),
    Rule("closed-source-list", "error", rule_closed_source_list),
    Rule("source-file", "error", rule_source_file),
    Rule("source-pinned", "error", rule_source_pinned),
    Rule("source-pinned-draft", "warning", rule_source_pinned_draft),
    Rule("source-quote", "error", rule_source_quote),
    Rule("source-quote-unverifiable", "warning",
         rule_source_quote_unverifiable),
    Rule("citation-overreach", "warning", rule_citation_overreach),
]


# ============================================================================
# Vale engine
# ============================================================================
#
# Vale owns prose tokens and typography. It is an external binary with its own
# root config; this engine shells out to it and maps its JSON onto the shared
# finding shape. Vale is a hard dependency: `require_vale` exits the run when
# the binary is absent, so a missing Vale fails loudly instead of silently
# dropping every prose check.


class LintEngineError(RuntimeError):
    """An external lint engine failed, so a clean result is impossible."""


def require_vale() -> None:
    if shutil.which("vale") is None:
        sys.stderr.write(
            "adoc_lint: `vale` is required but was not found on PATH. "
            "Install Vale (see README, Linting).\n")
        sys.exit(2)


def require_safe_vale_scopes(styles_dir: str = ".vale/styles") -> None:
    """Reject Vale scopes that are incomplete for AsciiDoc prose contexts.

    Vale does not apply `sentence` or `paragraph` styles to direct list-item
    and inline-admonition text. Those checks must live in the structural
    engine, whose author-unit iterator covers every supported prose context.
    Failing here prevents a newly added Vale style from silently reopening the
    same coverage hole.
    """
    unsafe = []
    for root, _, files in os.walk(styles_dir):
        for name in files:
            if not name.endswith((".yml", ".yaml")):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8") as style_file:
                match = re.search(
                    r"^scope:\s*(sentence|paragraph)\s*$",
                    style_file.read(), re.MULTILINE)
            if match:
                unsafe.append((path, match.group(1)))
    if unsafe:
        details = ", ".join(f"{path} ({scope})" for path, scope in unsafe)
        raise LintEngineError(
            "Vale sentence/paragraph scopes are incomplete for AsciiDoc "
            "lists and admonitions; move these checks to the structural "
            f"engine: {details}")


def _vale_data(proc: subprocess.CompletedProcess, context: str) -> dict:
    if proc.returncode not in (0, 1):
        detail = (proc.stderr or proc.stdout or "no diagnostic output").strip()
        raise LintEngineError(
            f"Vale failed while linting {context} (exit {proc.returncode}): "
            f"{detail}")
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as exc:
        detail = (proc.stderr or proc.stdout or "empty output").strip()
        raise LintEngineError(
            f"Vale returned invalid JSON while linting {context}: "
            f"{detail}") from exc
    if not isinstance(data, dict):
        raise LintEngineError(
            f"Vale returned an unexpected JSON value while linting {context}")
    return data


# Vale must lint the claim prose around a citation but never the quote inside
# it: the quote is the source's wording, not the author's. Filtering Vale's
# findings by their reported positions would trust Vale's drift-prone column
# mapping, so the exclusion happens on the input instead: Vale lints a shadow
# copy of the document in which each citation quote's delimiters `"+...+"` are
# swapped to `` `+...+` `` -- same length, so every line and column maps back
# 1:1 -- and Vale skips the resulting code span natively. The shadow file is
# written beside the source (config discovery walks up from the file) with the
# source's own suffix, so language-specific styles still apply.

def _vale_shadow(doc: Document) -> Optional[str]:
    ana = source_analysis(doc)
    spans: Dict[int, List[Tuple[int, int]]] = {}
    for cf in ana.citations:
        spans.setdefault(cf.line, []).append((cf.start_col, cf.end_col))
    has_code = any("`" in line.text for line in doc.lines)
    if not spans and not has_code:
        return None
    lines = []
    for line in doc.lines:
        text = line.text
        for start, end in spans.get(line.num, ()):
            seg = text[start - 1:end - 1]
            seg = seg.replace('"+', "`+").replace('+"', "+`")
            text = text[:start - 1] + seg + text[end - 1:]
        # Blank every inline code span's content (chars between backticks -> x,
        # length preserved) so a technical literal like `example.com` can't reach a
        # prose style even when Vale's AsciiDoc parser fails to segment a code
        # span inside a table cell.
        text = CODE_SPAN_RE.sub(
            lambda m: re.sub(r"[^`]", "x", m.group(0)), text)
        lines.append(text)
    return "\n".join(lines) + "\n"


def run_vale(path: str, doc: Document) -> List[tuple]:
    shadow = _vale_shadow(doc)
    target, tmp = path, None
    if shadow is not None:
        src_dir = os.path.dirname(path) or "."
        suffix = ".pl.adoc" if path.endswith(".pl.adoc") else ".adoc"
        with tempfile.NamedTemporaryFile(
                "w", suffix=suffix, dir=src_dir, delete=False,
                encoding="utf-8") as tf:
            tf.write(shadow)
            tmp = tf.name
        target = tmp
    try:
        proc = subprocess.run(
            ["vale", "--output=JSON", target],
            capture_output=True, text=True,
        )
    finally:
        if tmp is not None:
            os.unlink(tmp)
    data = _vale_data(proc, path)
    findings = []
    for alerts in data.values():
        for alert in alerts:
            span = alert.get("Span") or [1]
            findings.append((
                alert.get("Line", 1),
                span[0],
                alert.get("Check", "Vale"),
                alert.get("Severity", "error"),
                alert.get("Message", ""),
            ))
    return findings


# A table cell holds ordinary prose, but Vale's AsciiDoc parser never segments
# cell text into `sentence`/`paragraph` scopes. The structural punctuation
# rules above own the known scope-sensitive checks. This pass remains as a
# future-proof backstop for another non-text Vale style enabled later: lift
# each cell into a clean prose document, lint it, and map the finding back to
# the exact source line and cell offset.

def _vale_scope(check: str) -> str:
    """The `scope:` a Vale style declares, read from its style file at runtime
    (like `_vale_cap`), or 'text' when it declares none or has no file. Reading
    it here means the table pass tracks the styles on disk, not a list restated
    in code that would drift as styles are added."""
    style, _, rule = check.partition(".")
    path = os.path.join(".vale/styles", style, rule + ".yml")
    try:
        with open(path, encoding="utf-8") as f:
            m = re.search(r"^scope:\s*(\S+)", f.read(), re.M)
    except OSError:
        return "text"
    return m.group(1) if m else "text"


def run_vale_tables(doc: Document) -> List[tuple]:
    cells = list(_table_cells(doc))
    if not cells:
        return []

    body: List[str] = []
    para_src: Dict[int, Tuple[int, int]] = {}  # temp line -> (src line, src col)
    for prose, src_line, src_col in cells:
        para_src[len(body) + 1] = (src_line, src_col)
        body.append(prose)
        body.append("")  # a blank line keeps each cell its own paragraph

    # Write the temp file beside the source so Vale discovers the same
    # `.vale.ini` it would for the real document (config lookup walks up from
    # the file), and give it the `.adoc` suffix the config's glob matches.
    src_dir = os.path.dirname(doc.path) or "."
    with tempfile.NamedTemporaryFile(
            "w", suffix=".adoc", dir=src_dir, delete=False,
            encoding="utf-8") as tf:
        tf.write("\n".join(body) + "\n")
        tmp = tf.name
    try:
        proc = subprocess.run(
            ["vale", "--output=JSON", tmp], capture_output=True, text=True)
    finally:
        os.unlink(tmp)
    data = _vale_data(proc, f"table cells in {doc.path}")

    findings = []
    for alerts in data.values():
        for alert in alerts:
            check = alert.get("Check", "Vale")
            scope = _vale_scope(check)
            if scope in ("text", "summary") or scope.startswith("head"):
                continue  # body pass covers text; a cell is never a heading
            src = para_src.get(alert.get("Line", 0))
            if src is None:
                continue
            span = alert.get("Span") or [1]
            findings.append((
                src[0],
                src[1] + max(span[0] - 1, 0),
                check,
                alert.get("Severity", "error"),
                alert.get("Message", ""),
            ))
    return findings


# ============================================================================
# Asciidoctor engine -- render integrity
# ============================================================================
#
# A document that doesn't render cleanly is broken regardless of its prose:
# a missing include drops content silently, and malformed markup renders as
# literal text. Asciidoctor is run as a render pass with the output discarded,
# and every WARNING-or-worse message it logs becomes an error finding. Like
# Vale, Asciidoctor is a hard dependency that fails loudly when absent.
# Asciidoctor does not validate internal cross-references (an `xref` to a
# missing id converts silently); the structural rule `xref-targets` owns that.

ASCIIDOCTOR_MSG_RE = re.compile(
    r"^asciidoctor: ([A-Z]+): (?:(.*?): line (\d+): )?(.*)$")
ASCIIDOCTOR_GATING = {"WARNING", "ERROR", "FAILED", "FATAL"}
RENDERED_FOOTNOTE_RE = re.compile(r"footnote:([\w-]*)\[")
RENDERED_QUOTED_PASS_RE = re.compile(r'"\+(.*?)\+"')


class _RenderedMacroParser(HTMLParser):
    """Collect unexpanded inline markup from visible, non-code HTML text."""

    _excluded = {"code", "pre", "script", "style"}

    def __init__(self) -> None:
        super().__init__()
        self.excluded_depth = 0
        self.footnotes: List[str] = []
        self.quoted_passes: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[tuple]) -> None:
        if tag in self._excluded:
            self.excluded_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in self._excluded and self.excluded_depth:
            self.excluded_depth -= 1

    def handle_data(self, data: str) -> None:
        if self.excluded_depth:
            return
        self.footnotes.extend(m.group(1)
                              for m in RENDERED_FOOTNOTE_RE.finditer(data))
        self.quoted_passes.extend(m.group(1)
                                  for m in RENDERED_QUOTED_PASS_RE.finditer(data))


def require_asciidoctor() -> None:
    if shutil.which("asciidoctor") is None:
        sys.stderr.write(
            "adoc_lint: `asciidoctor` is required but was not found on PATH. "
            "Install Asciidoctor (see README, Linting).\n")
        sys.exit(2)


def require_pdftotext() -> None:
    """pdftotext (poppler) extracts the text the source-quote rule greps in
    PDF sources. Like vale and asciidoctor it is a hard dependency: a missing
    binary fails loudly instead of silently skipping the quote checks."""
    if shutil.which("pdftotext") is None:
        sys.stderr.write(
            "adoc_lint: `pdftotext` is required but was not found on PATH. "
            "Install poppler (see README, Linting).\n")
        sys.exit(2)


def require_tesseract() -> None:
    """tesseract reads the OCR text the source-quote rule searches for quotes
    cited from image sources. The binary is a hard dependency like pdftotext;
    an OCR miss still only warns, because OCR is lossy."""
    if shutil.which("tesseract") is None:
        sys.stderr.write(
            "adoc_lint: `tesseract` is required but was not found on PATH. "
            "Install tesseract (see README, Linting).\n")
        sys.exit(2)


def run_asciidoctor(path: str) -> List[tuple]:
    with tempfile.NamedTemporaryFile(suffix=".html", delete=False) as tf:
        rendered_path = tf.name
    try:
        proc = subprocess.run(
            ["asciidoctor", "--out-file", rendered_path, path],
            capture_output=True, text=True,
        )
        with open(rendered_path, encoding="utf-8") as rendered_file:
            rendered = rendered_file.read()
    finally:
        os.unlink(rendered_path)
    findings = []
    for raw in proc.stderr.splitlines():
        m = ASCIIDOCTOR_MSG_RE.match(raw.strip())
        if not m or m.group(1) not in ASCIIDOCTOR_GATING:
            continue
        line = int(m.group(3)) if m.group(3) else 1
        findings.append((line, 1, "asciidoctor", "error",
                         f"Asciidoctor {m.group(1).lower()}: {m.group(4)}"))

    parser = _RenderedMacroParser()
    parser.feed(rendered)
    with open(path, encoding="utf-8") as source_file:
        source_lines = source_file.read().splitlines()
    seen = set()
    for footnote_id in parser.footnotes:
        marker = f"footnote:{footnote_id}["
        line = next((num for num, text in enumerate(source_lines, 1)
                     if marker in text), 1)
        key = (line, footnote_id)
        if key in seen:
            continue
        seen.add(key)
        findings.append((
            line, 1, "asciidoctor", "error",
            "Asciidoctor left a footnote macro literal in rendered prose; "
            "check for an earlier unescaped inline delimiter",
        ))
    for quote in parser.quoted_passes:
        marker = f'"+{quote}+"'
        line = next((num for num, text in enumerate(source_lines, 1)
                     if marker in text), 1)
        key = (line, quote)
        if key in seen:
            continue
        seen.add(key)
        findings.append((
            line, 1, "asciidoctor", "error",
            "Asciidoctor left citation passthrough plus signs in rendered "
            "prose; check for a conflicting inline delimiter on the line",
        ))
    return findings


# ============================================================================
# Driver
# ============================================================================

def filter_vale_citations(findings: List[tuple], doc: Document) -> List[tuple]:
    """Drop Vale findings inside the source-citation apparatus. Bibliography
    entries are records whose vocabulary (ids, hashes, surnames, format
    names) isn't the author's prose, and a citation footnote's locator and
    quote are governed by the citation grammar, not the prose rules -- both
    are owned by the structural citation rules instead. The bibliography test
    is line-ranged and immune to Vale's column drift; the footnote test drops
    a finding whose start column falls inside the macro span."""
    ana = source_analysis(doc)
    if not ana.bib_attr_line and not ana.citations:
        return findings
    spans: Dict[int, List[Tuple[int, int]]] = {}
    for cf in ana.citations:
        spans.setdefault(cf.line, []).append((cf.start_col, cf.end_col))
    kept = []
    for f in findings:
        line, col = f[0], f[1]
        if _in_bib(ana, line):
            continue
        if any(start <= col < end for start, end in spans.get(line, ())):
            continue
        kept.append(f)
    return kept


def lint_file(path: str) -> Tuple[List[tuple], List[Tuple[str, str]]]:
    doc = scan(path)
    findings: List[tuple] = []

    for rule in RULES:
        if not rule.enabled:
            continue
        for line, col, message in rule.func(doc):
            findings.append((line, col, rule.id, rule.severity, message))

    findings.extend(filter_vale_citations(run_vale(path, doc), doc))
    findings.extend(filter_vale_citations(run_vale_tables(doc), doc))
    findings.extend(run_asciidoctor(path))
    findings.sort(key=lambda f: (f[0], f[1], f[2]))
    return findings, file_diagnostics(doc)


# ============================================================================
# Text output -- grouped, coloured, with a summary
# ============================================================================
#
# Colour is emitted only to a real terminal, so piped or agent-captured output
# (and `--format json`) stays plain. A run with no findings still prints a green
# summary line with the counts, so a clean check reads as a positive result
# rather than as silence.

SEVERITY_ORDER = {"error": 0, "warning": 1, "suggestion": 2}
SEVERITY_COLOR = {"error": "31", "warning": "33", "suggestion": "36"}


class Style:
    def __init__(self, enabled: bool):
        self.enabled = enabled

    def paint(self, code: str, text: str) -> str:
        return f"\033[{code}m{text}\033[0m" if self.enabled else text


def _plural(n: int, noun: str) -> str:
    return f"{n} {noun}" + ("" if n == 1 else "s")


def render_text(file_results: List[tuple], style: Style, n_rules: int,
                elapsed: float) -> str:
    findings = [(p, f) for p, fs, _ in file_results for f in fs]
    loc_w = max((len(f"{f[0]}:{f[1]}") for _, f in findings), default=0)
    sev_w = max((len(f[3]) for _, f in findings), default=0)

    out: List[str] = []
    for path, fs, diagnostics in file_results:
        out.append("")
        out.append(" " + style.paint("1;4", path))
        label_w = max((len(label) for label, _ in diagnostics), default=0)
        for label, text in diagnostics:
            out.append("   " + style.paint("2", f"{label.ljust(label_w)}  "
                                                f"{text}"))
        for line, col, rule_id, severity, message in fs:
            loc = f"{line}:{col}".rjust(loc_w)
            sev = style.paint(SEVERITY_COLOR.get(severity, "31"),
                              severity.ljust(sev_w))
            out.append(f"   {style.paint('2', loc)}  {sev}  {message}  "
                       + style.paint('2', rule_id))

    n_files = len(file_results)
    counts = Counter(f[3] for _, f in findings)
    scope = style.paint("2", f"{_plural(n_files, 'file')} · "
                             f"{n_rules} structural rules + Vale "
                             f"+ Asciidoctor")
    timing = style.paint("2", f" · {elapsed:.2f}s")
    if findings:
        parts = ", ".join(
            _plural(counts[s], s) for s in
            sorted(counts, key=lambda s: SEVERITY_ORDER.get(s, 9)))
        files_hit = sum(1 for _, fs, _ in file_results if fs)
        out.append("")
        # Only errors fail the run; a warnings-only summary says so instead
        # of painting a failure glyph over a passing result.
        if counts.get("error"):
            out.append(" " + style.paint("1;31", f"✗ {parts}")
                       + style.paint("2",
                                     f"  in {_plural(files_hit, 'file')}")
                       + timing)
        else:
            out.append(" " + style.paint("1;32", "✓ Passed")
                       + " " + style.paint("1;33", f"with {parts}")
                       + style.paint("2",
                                     f"  in {_plural(files_hit, 'file')}")
                       + timing)
    else:
        out.append(" " + style.paint("1;32", "✓ No problems found")
                   + "  " + scope + timing)
    return "\n".join(out) + "\n"


def main(argv: List[str]) -> int:
    start = time.perf_counter()
    fmt = "text"
    no_color = False
    paths: List[str] = []
    it = iter(argv)
    for arg in it:
        if arg == "--format":
            fmt = next(it, "text")
        elif arg.startswith("--format="):
            fmt = arg.split("=", 1)[1]
        elif arg == "--no-color":
            no_color = True
        elif arg in ("-h", "--help"):
            sys.stdout.write(__doc__)
            return 0
        else:
            paths.append(arg)

    if not paths:
        sys.stderr.write(
            "Usage: adoc_lint.py [--format text|json] [--no-color] "
            "<file.adoc> [...]\n")
        return 2

    require_vale()
    require_asciidoctor()
    require_pdftotext()
    require_tesseract()

    try:
        require_safe_vale_scopes()
        file_results = [(path, *lint_file(path)) for path in paths]
    except LintEngineError as exc:
        sys.stderr.write(f"adoc_lint: {exc}\n")
        return 2
    elapsed = time.perf_counter() - start
    has_error = any(f[3] == "error" for _, fs, _ in file_results for f in fs)

    if fmt == "json":
        sys.stdout.write(json.dumps([
            {"path": p, "line": f[0], "col": f[1],
             "rule": f[2], "severity": f[3], "message": f[4]}
            for p, fs, _ in file_results for f in fs
        ], indent=2) + "\n")
    else:
        enabled = (not no_color and sys.stdout.isatty()
                   and os.environ.get("NO_COLOR") is None)
        sys.stdout.write(render_text(file_results, Style(enabled), len(RULES),
                                     elapsed))

    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
