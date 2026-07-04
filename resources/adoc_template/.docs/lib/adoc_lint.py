#!/usr/bin/env python3
"""Lint an AsciiDoc document against the deterministic rules of the guideline.

The linter runs three engines and merges their findings into one stream:

  1. Vale (an external binary) for prose tokens and typography. Its config
     lives at the project root in `.vale.ini` + `.vale/styles/`. Vale is
     required: when the `vale` binary is not on PATH, the linter exits with an
     error rather than silently skipping the prose checks.
  2. The structural engine in this file for the markup, tree, and ASCII-diagram
     rules that Vale cannot see, because Vale lints rendered prose and loses the
     markup layer (heading depth, list nesting, anchor syntax, box-drawing).
  3. Asciidoctor (an external binary) as a render pass: the document is
     converted to a discarded output file and every WARNING-or-worse message
     (missing includes, malformed markup) is mapped onto the finding stream.
     Asciidoctor does NOT validate internal cross-references, so the
     structural rule `xref-targets` covers that gap.

Only the mechanically-checkable slice of `README-guideline-writing.adoc` is enforced
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
# List structure — continuations and starts that render as literal text
# ============================================================================
#
# A render-integrity pair. AsciiDoc's list markup fails silently in two ways
# that Asciidoctor's own render pass does NOT report (verified empirically: both
# convert with exit 0 and no warning), so the literal markers reach the reader
# as body text. These two rules are the deterministic, precisely-located
# backstop the render pass can't give:
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
# Both run in prose (`none`) blocks only, so markers shown inside a `[source]`
# example, or a `+` standing in a table cell (a legal cell continuation), are
# left alone. Each flags only the single line that breaks the structure -- the
# stray `+` or the glued first item -- since fixing it repairs the cascade below.

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
# Paragraph and section size — sentence caps, body caps, opener monotony
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
BLOCK_ANCHOR_FULL_RE = re.compile(r"\[\[[^\]]*\]\]")

MAX_SENTENCES_PER_PARAGRAPH = 8
MAX_SECTION_BODY_WORDS = 600
MAX_OPENER_RUN = 4


def _rendered(text: str) -> str:
    """Approximate the rendered prose of a source line: code spans masked,
    macros replaced by their display text, anchors dropped."""
    t = _mask_code(text)
    t = XREF_TEXT_RE.sub(r"\1", t)
    t = LINK_RE.sub(r"\1", t)
    t = BLOCK_ANCHOR_FULL_RE.sub(" ", t)
    return t


def _paragraphs(doc: Document) -> Iterator[Line]:
    """Prose content lines: paragraphs and list items, without headings,
    block titles, metadata, tables, or macros standing alone."""
    for line in doc.lines:
        if line.block != "none" or line.in_table:
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
# Abstractness — graded-lexicon vocabulary check (English)
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
#     cap. The suffix-based English.Nominalizations Vale rule is the
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
# Diagnostics — per-file metrics panel
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
    if is_english and max_abstract[1]:
        mean, count, line_num, part = max_abstract
        rows.append(("abstractness",
                     f"cap {MAX_MEAN_ABSTRACTNESS} · max {mean:.1f} over "
                     f"{count} graded words (line {line_num}): "
                     f"{_top_abstract_words(part, lexicon)}"))
    elif not is_english:
        rows.append(("abstractness", "skipped (Polish document)"))
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
    Rule("xref-targets", "error", rule_xref_targets),
    Rule("one-paragraph-one-topic", "error", rule_paragraph_sentences),
    Rule("section-body-length", "error", rule_section_body_words),
    Rule("sentence-opener-runs", "error", rule_sentence_opener_runs),
    Rule("sentence-length", "error", rule_sentence_length),
    Rule("concrete-vocabulary", "error", rule_abstract_vocabulary),
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
# Asciidoctor engine — render integrity
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


def require_asciidoctor() -> None:
    if shutil.which("asciidoctor") is None:
        sys.stderr.write(
            "adoc_lint: `asciidoctor` is required but was not found on PATH. "
            "Install Asciidoctor (see README, Linting).\n")
        sys.exit(2)


def run_asciidoctor(path: str) -> List[tuple]:
    proc = subprocess.run(
        ["asciidoctor", "--out-file", os.devnull, path],
        capture_output=True, text=True,
    )
    findings = []
    for raw in proc.stderr.splitlines():
        m = ASCIIDOCTOR_MSG_RE.match(raw.strip())
        if not m or m.group(1) not in ASCIIDOCTOR_GATING:
            continue
        line = int(m.group(3)) if m.group(3) else 1
        findings.append((line, 1, "asciidoctor", "error",
                         f"Asciidoctor {m.group(1).lower()}: {m.group(4)}"))
    return findings


# ============================================================================
# Driver
# ============================================================================

def lint_file(path: str) -> Tuple[List[tuple], List[Tuple[str, str]]]:
    doc = scan(path)
    findings: List[tuple] = []

    for rule in RULES:
        if not rule.enabled:
            continue
        for line, col, message in rule.func(doc):
            findings.append((line, col, rule.id, rule.severity, message))

    findings.extend(run_vale(path))
    findings.extend(run_asciidoctor(path))
    findings.sort(key=lambda f: (f[0], f[1], f[2]))
    return findings, file_diagnostics(doc)


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
    if findings:
        parts = ", ".join(
            _plural(counts[s], s) for s in
            sorted(counts, key=lambda s: SEVERITY_ORDER.get(s, 9)))
        files_hit = sum(1 for _, fs, _ in file_results if fs)
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
    require_asciidoctor()

    file_results = [(path, *lint_file(path)) for path in paths]
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
        sys.stdout.write(render_text(file_results, Style(enabled), len(RULES)))

    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
