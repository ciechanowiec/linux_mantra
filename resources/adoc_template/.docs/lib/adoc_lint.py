#!/usr/bin/env python3
"""Lint an AsciiDoc document against the deterministic rules of the guideline.

The linter runs two engines and merges their findings into one stream:

  1. Vale (an external binary) for prose tokens and typography. Its config
     lives at the project root in `.vale.ini` + `.vale/styles/`. Vale is
     required: when the `vale` binary is not on PATH, the linter exits with an
     error rather than silently skipping the prose checks.
  2. The structural engine in this file for the markup, tree, and ASCII-diagram
     rules that Vale cannot see, because Vale lints rendered prose and loses the
     markup layer (heading depth, list nesting, anchor syntax, box-drawing).

Only the mechanically-checkable slice of `README-guideline.adoc` is enforced
here. Rules of prose judgement (nomenclature drift, false universals, "don't
invent facts") need a reader of the guideline, not a linter, and are out of
scope by design.

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
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from typing import Callable, Dict, Iterator, List, Tuple

Finding = Tuple[int, int, str]  # (line, col, message) yielded by a rule
RuleFunc = Callable[["Document"], Iterator[Finding]]


# ============================================================================
# Source model — a block-aware line scanner
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


def _mask_code(text: str) -> str:
    return CODE_SPAN_RE.sub(lambda m: " " * len(m.group(0)), text)


# ============================================================================
# Heading tree — depth and lone subsections
# ============================================================================
#
# Serves section-nesting (README-guideline §section-nesting): a heading nests
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
# List markers — numbering depth
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
# Images — alt text
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
# Links — descriptive text
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


def rule_link_text(doc: Document) -> Iterator[Finding]:
    for line in _prose(doc):
        for m in LINK_RE.finditer(_mask_code(line.text)):
            text = m.group(1).rstrip("^").strip().lower()
            if text in NONDESCRIPTIVE:
                yield (line.num, m.start() + 1,
                       f"Non-descriptive link text {m.group(1)!r} that should "
                       f"wrap the phrase the source substantiates "
                       f"(§link-text-carries-the-claim)")


# ============================================================================
# Anchors — explicit ids, kebab-case
# ============================================================================
#
# Serves explicit-anchors (§explicit-anchors): a cross-reference targets an
# explicit anchor, never an auto-generated id. An auto-generated id starts
# with `_` (Asciidoctor derives it from the heading text), so a reference to
# `<<_foo>>` or `xref:_foo` breaks the moment the heading is retitled. An
# explicit anchor id is lowercase kebab-case; uppercase, whitespace, or `_`
# in an id is a defect.

AUTO_ANCHOR_RE = re.compile(r"(?:<<|xref:#?)_[\w-]+")
BLOCK_ANCHOR_RE = re.compile(r"\[\[([^\],]+)")
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


# ============================================================================
# ASCII diagrams — character hygiene
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
# never mistaken for a corner.


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
                if up in "|+" or down in "|+":
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
# Prose markup — line and inline heuristics
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
# standalone `*Header*` line (a paragraph header) and a `* item` list marker
# are excluded.

# A paragraph header (§paragraph-headers) is a bold phrase standing as a whole
# list item, optionally behind a list marker and an anchor: `. *Security*`,
# `.. [[id]]*Live metrics*`. Bold is licensed there, so such a line is skipped;
# bold appearing mid-sentence is not.
PARAGRAPH_HEADER_RE = re.compile(
    r"^(?:[.*]+\s+)?(?:\[\[[^\]]*\]\]|\[#[^\]]*\])?\s*\*[^*]+\*\s*$")
BOLD_IN_BODY_RE = re.compile(r"(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])")


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
        if PARAGRAPH_HEADER_RE.match(stripped):
            continue
        if UNORDERED_MARKER_RE.match(line.text):
            continue
        for m in BOLD_IN_BODY_RE.finditer(_mask_code(line.text)):
            yield (line.num, m.start() + 1,
                   "Bold in body text where a word carrying emphasis should be "
                   "italic (§inline-formatting-semantics)")


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
    Rule("alt-text", "error", rule_image_alt_text),
    Rule("link-text", "error", rule_link_text),
    Rule("explicit-anchors", "error", rule_auto_anchor),
    Rule("anchor-format", "error", rule_anchor_format),
    Rule("diagram-tabs", "error", rule_diagram_tabs),
    Rule("diagram-trailing-space", "error", rule_diagram_trailing_space),
    Rule("diagram-charset", "error", rule_diagram_charset),
    Rule("diagram-box-alignment", "error", rule_diagram_box_alignment),
    Rule("diagram-corner-support", "error", rule_diagram_corner_support),
    Rule("diagram-lifeline-alignment", "error", rule_diagram_lifeline_alignment),
    Rule("one-sentence-per-line", "error", rule_one_sentence_per_line),
    Rule("inline-formatting", "error", rule_bold_in_body),
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


def require_vale() -> None:
    if shutil.which("vale") is None:
        sys.stderr.write(
            "adoc_lint: `vale` is required but was not found on PATH. "
            "Install Vale (see README, Linting).\n")
        sys.exit(2)


def run_vale(path: str) -> List[tuple]:
    proc = subprocess.run(
        ["vale", "--output=JSON", path],
        capture_output=True, text=True,
    )
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        sys.stderr.write("adoc_lint: could not parse Vale output, "
                         "skipping prose checks\n")
        return []
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


# ============================================================================
# Driver
# ============================================================================

def lint_file(path: str) -> List[tuple]:
    doc = scan(path)
    findings: List[tuple] = []

    for rule in RULES:
        if not rule.enabled:
            continue
        for line, col, message in rule.func(doc):
            findings.append((line, col, rule.id, rule.severity, message))

    findings.extend(run_vale(path))
    findings.sort(key=lambda f: (f[0], f[1], f[2]))
    return findings


# ============================================================================
# Text output — grouped, coloured, with a summary
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


def render_text(file_results: List[tuple], style: Style, n_rules: int) -> str:
    findings = [(p, f) for p, fs in file_results for f in fs]
    loc_w = max((len(f"{f[0]}:{f[1]}") for _, f in findings), default=0)
    sev_w = max((len(f[3]) for _, f in findings), default=0)

    out: List[str] = []
    for path, fs in file_results:
        if not fs:
            continue
        out.append("")
        out.append(" " + style.paint("1;4", path))
        for line, col, rule_id, severity, message in fs:
            loc = f"{line}:{col}".rjust(loc_w)
            sev = style.paint(SEVERITY_COLOR.get(severity, "31"),
                              severity.ljust(sev_w))
            out.append(f"   {style.paint('2', loc)}  {sev}  {message}  "
                       + style.paint('2', rule_id))

    n_files = len(file_results)
    counts = Counter(f[3] for _, f in findings)
    scope = style.paint("2", f"{_plural(n_files, 'file')} · "
                             f"{n_rules} structural rules + Vale")
    if findings:
        parts = ", ".join(
            _plural(counts[s], s) for s in
            sorted(counts, key=lambda s: SEVERITY_ORDER.get(s, 9)))
        files_hit = sum(1 for _, fs in file_results if fs)
        out.append("")
        out.append(" " + style.paint("1;31", f"✗ {parts}")
                   + style.paint("2", f"  in {_plural(files_hit, 'file')}"))
    else:
        out.append(" " + style.paint("1;32", "✓ No problems found")
                   + "  " + scope)
    return "\n".join(out) + "\n"


def main(argv: List[str]) -> int:
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

    file_results = [(path, lint_file(path)) for path in paths]
    has_error = any(f[3] == "error" for _, fs in file_results for f in fs)

    if fmt == "json":
        sys.stdout.write(json.dumps([
            {"path": p, "line": f[0], "col": f[1],
             "rule": f[2], "severity": f[3], "message": f[4]}
            for p, fs in file_results for f in fs
        ], indent=2) + "\n")
    else:
        enabled = (not no_color and sys.stdout.isatty()
                   and os.environ.get("NO_COLOR") is None)
        sys.stdout.write(render_text(file_results, Style(enabled), len(RULES)))

    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
