// Autofit wide verbatim blocks: shrink each <pre> whose content overflows its
// box just enough to fit, so wide ASCII diagrams and code render whole instead
// of wrapping. Mirrors the autofit applied on the PDF side. Below the block's
// minimum scale the text stays at its normal size and wraps as before.
//
// The floor is per-block, because the two cases differ: in a multi-line block
// every line matters and wrapping would break the alignment, so heavy shrinking
// is worth it. A single-line block is usually a prose sentence that reads fine
// once wrapped, so shrinking it to a tiny size (as a long one-liner would force)
// looks worse than just letting it wrap at full size — such blocks only get a
// gentle nudge to avoid an awkward wrap, and otherwise wrap normally.
(function () {
    var MIN_SCALE_MULTILINE = 0.55;
    var MIN_SCALE_SINGLELINE = 0.85;
    var autofitPre = function () {
        var pres = document.querySelectorAll('.literalblock pre, .listingblock pre');
        pres.forEach(function (pre) {
            pre.style.fontSize = '';
            pre.style.whiteSpace = 'pre';   // unwrap to measure the true width
            var scale = pre.clientWidth / pre.scrollWidth;
            var singleLine = pre.textContent.replace(/\n+$/, '').indexOf('\n') === -1;
            var minScale = singleLine ? MIN_SCALE_SINGLELINE : MIN_SCALE_MULTILINE;
            if (scale >= 1 || scale < minScale) {
                pre.style.whiteSpace = '';  // fits, or too wide: keep default wrap
                return;
            }
            var base = parseFloat(window.getComputedStyle(pre).fontSize);
            pre.style.fontSize = (base * scale * 0.98) + 'px';
        });
    };
    window.addEventListener('resize', autofitPre);
    autofitPre();
})();

// Footnote hover preview: a footnote carries the citation for the statement it hangs off,
// so following one otherwise costs a jump to the foot of the page and the reader's place.
// Show the note's own content beside the reference on hover or keyboard focus, and keep it
// open while the pointer rests on it so any links inside stay reachable. HTML only: the PDF
// renders real footnotes at the foot of the page, and the DOCX export loads no docinfo.
(function () {
    var HIDE_DELAY_MS = 180;             // grace period once the pointer is already at the note
    var TRAVEL_SPEED_PX_PER_MS = 0.8;    // an unhurried pointer, not a flick
    var MAX_TRAVEL_MS = 1400;            // a stuck-open note is worse than a lost one
    var AWAY_TOLERANCE_PX = 60;          // absorbs the wobble of an imprecise but honest approach
    var popover;
    var hideTimer;
    var hidePending = false;   // the mousemove watcher only arbitrates a hide already scheduled
    var distanceAtLeave;

    var cancelHide = function () {
        window.clearTimeout(hideTimer);
        hidePending = false;
    };

    var distanceToNote = function (event) {
        if (!popover || popover.style.display === 'none' || !event || typeof event.clientX !== 'number') {
            return 0;
        }
        var box = popover.getBoundingClientRect();
        var dx = Math.max(box.left - event.clientX, 0, event.clientX - box.right);
        var dy = Math.max(box.top - event.clientY, 0, event.clientY - box.bottom);
        return Math.sqrt(dx * dx + dy * dy);
    };

    var element = function () {
        if (!popover) {
            popover = document.createElement('div');
            popover.className = 'fn-pop';
            popover.setAttribute('role', 'tooltip');
            popover.addEventListener('mouseenter', cancelHide);
            popover.addEventListener('mouseleave', scheduleHide);
            document.body.appendChild(popover);
        }
        return popover;
    };

    // The definition opens with a back-reference link and an "N." label. The popover repeats
    // neither, because the reader is already standing on that reference.
    var contentOf = function (link) {
        var definition = document.getElementById((link.getAttribute('href') || '').slice(1));
        if (!definition) {
            return '';
        }
        var clone = definition.cloneNode(true);
        var back = clone.querySelector('a[href^="#_footnoteref_"]');
        if (back) {
            back.parentNode.removeChild(back);
        }
        return clone.innerHTML.replace(/^\s*\.\s*/, '').trim();
    };

    // A footnote marker sits at the end of the claim it cites, and prose wraps, so the claim
    // occupies the marker's own line and the lines above it. Placing the note above therefore
    // hides the very text the reader opened it to check. Preferred placement is the margin
    // beside the text column, where nothing is covered at all; where the window is too narrow
    // for that, below the marker, which at worst covers the *next* sentence.
    var SIDE_MIN_WIDTH_PX = 240;   // narrower than this a margin note reads as a ransom note
    var SIDE_MAX_WIDTH_PX = 380;
    var GAP_PX = 12;

    var show = function (link) {
        cancelHide();
        var html = contentOf(link);
        if (!html) {
            return;
        }
        var pop = element();
        pop.innerHTML = html;
        pop.classList.remove('fn-pop--side');   // placement is decided fresh on every open
        pop.style.width = '';
        pop.style.visibility = 'hidden';        // measure before placing, so it never flashes
        pop.style.display = 'block';

        var anchor = link.getBoundingClientRect();
        // The margin starts at the right edge of the content column, not of the marker's own
        // block: an indented block (admonition, nested list) sits inside the column, and a note
        // pinned to its edge would still overlap prose belonging to the column.
        var content = document.getElementById('content');
        var columnRight = content ? content.getBoundingClientRect().right : anchor.right;
        // clientWidth, not innerWidth: the latter counts the scrollbar, which would let the
        // note sit under it.
        var viewportWidth = document.documentElement.clientWidth;
        var margin = viewportWidth - columnRight - 2 * GAP_PX;
        var left;
        var top;

        if (margin >= SIDE_MIN_WIDTH_PX) {
            pop.classList.add('fn-pop--side');
            pop.style.width = Math.min(margin, SIDE_MAX_WIDTH_PX) + 'px';
            left = columnRight + GAP_PX;
            top = anchor.top + anchor.height / 2 - pop.offsetHeight / 2;   // centred on the marker
            top = Math.min(Math.max(GAP_PX, top), Math.max(GAP_PX, window.innerHeight - pop.offsetHeight - GAP_PX));
        } else {
            left = Math.min(Math.max(8, anchor.left), Math.max(8, viewportWidth - pop.offsetWidth - 8));
            var fitsBelow = window.innerHeight - anchor.bottom > pop.offsetHeight + GAP_PX;
            top = fitsBelow ? anchor.bottom + 8 : anchor.top - pop.offsetHeight - 8;
        }

        pop.style.left = (left + window.pageXOffset) + 'px';
        pop.style.top = (top + window.pageYOffset) + 'px';
        pop.style.visibility = 'visible';
    };

    var hide = function () {
        hidePending = false;
        if (popover) {
            popover.style.display = 'none';
        }
    };

    // In margin mode the note can sit a full column away from its marker — a marker at the start
    // of a line is the worst case — so a delay tuned for an adjacent note expires mid-journey.
    // Budget for the gap the pointer actually has to cross. Budgeting that generously would
    // leave the note hanging whenever the reader *isn't* heading for it, so the companion
    // mousemove below cuts the wait short as soon as the pointer commits to going elsewhere.
    function scheduleHide(event) {
        window.clearTimeout(hideTimer);
        distanceAtLeave = distanceToNote(event);
        hidePending = true;
        hideTimer = window.setTimeout(hide, HIDE_DELAY_MS + Math.min(distanceAtLeave / TRAVEL_SPEED_PX_PER_MS, MAX_TRAVEL_MS));
    }

    document.addEventListener('mousemove', function (event) {
        if (!hidePending) {
            return;
        }
        if (distanceToNote(event) > distanceAtLeave + AWAY_TOLERANCE_PX) {
            hide();   // committed to going elsewhere; no reason to keep waiting
        }
    });

    document.querySelectorAll('a.footnote[href^="#_footnotedef_"]').forEach(function (link) {
        link.removeAttribute('title');   // the native "View footnote." tooltip would fight the popover
        link.addEventListener('mouseenter', function () { show(link); });
        link.addEventListener('mouseleave', scheduleHide);
        link.addEventListener('focus', function () { show(link); });
        link.addEventListener('blur', hide);
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            hide();
        }
    });

    // Placement is measured once, at open time. A resize invalidates it — margin mode may no
    // longer fit, and the marker has moved — so drop the note rather than leave it stranded.
    window.addEventListener('resize', hide);
})();

// Internal-link hover preview: a cross-reference asks the reader to go elsewhere in the
// document to recover one definition, and the jump costs them the place they were holding.
// Show the referenced text beside the link on hover or keyboard focus instead, and keep it
// open while the pointer rests on it. Deliberately separate from the footnote preview above:
// the two answer different questions — a footnote quotes a whole short note written to be read
// on its own, while this quotes a fragment of a longer document and has to decide which
// fragment that is. HTML only, like the footnote preview; the PDF and DOCX exports carry
// neither the behaviour nor the docinfo that would load it.
(function () {
    var SHOW_DELAY_MS = 140;
    var HIDE_DELAY_MS = 180;
    var TRAVEL_SPEED_PX_PER_MS = 0.8;
    var MAX_TRAVEL_MS = 1400;
    var AWAY_TOLERANCE_PX = 60;
    // Prose reflows, so a narrow margin still reads. A table laid out to a fixed width and a
    // verbatim block cannot reflow: squeezed into the same column they break words mid-token
    // and lose the alignment that made them worth showing, which costs the reader more than
    // the two lines the fallback placement covers. Each asks for the room it needs.
    var SIDE_MIN_WIDTH_PX = 240;
    var SIDE_MIN_WIDTH_RIGID_PX = 340;
    var RIGID_CONTENT_SELECTOR = 'table, pre';
    var SIDE_MAX_WIDTH_PX = 520;
    var PREFERRED_WIDTH_REM = 38;
    var GAP_PX = 12;
    var SECTION_SELECTOR = '.sect0, .sect1, .sect2, .sect3, .sect4, .sect5';
    // A colon ends an announcement, not an answer.
    var LEAD_IN_PATTERN = /:\s*$/;
    // A bold run standing alone announces the same way a colon does: "Purpose", "Worked example"
    // name what comes next instead of saying it. Sentence-ending punctuation marks a statement,
    // and length marks prose that merely happens to be emphasised, so both rule the label out.
    var LABEL_PATTERN = /[.!?:\u2026]\s*$/;
    var LABEL_MAX_CHARS = 60;
    // What a colon may introduce. Deliberately not a paragraph: prose following prose is the
    // next thought, not the completion of the previous one, and pulling it in doubles the
    // preview for no gain.
    var CONTINUATION_SELECTOR = [
        '.olist',
        '.ulist',
        '.dlist',
        '.listingblock',
        '.literalblock',
        '.admonitionblock',
        '.exampleblock',
        'table.tableblock'
    ].join(', ');
    // What a label may introduce, which is anything a colon may plus the prose the colon rule
    // declines: a label is a heading in all but markup, so the paragraph under it is not the
    // next thought, it is the only thought there is.
    var LABEL_CONTINUATION_SELECTOR = CONTINUATION_SELECTOR + ', .paragraph';
    // A label may introduce a lead-in, which in turn introduces a list or a block. Two hops
    // reach the end of that chain; a third would be quoting the section rather than sampling it.
    var MAX_CONTINUATIONS = 2;
    var CONTENT_SELECTOR = [
        '.paragraph > p',
        '.olist > ol > li > p',
        '.ulist > ul > li > p',
        '.dlist dd > p',
        '.admonitionblock td.content',
        '.listingblock pre',
        '.literalblock pre',
        'table.tableblock p'
    ].join(', ');
    var popover;
    var currentLink;
    var showTimer;
    var hideTimer;
    var hidePending = false;
    var distanceAtLeave = 0;

    var cancelShow = function () {
        window.clearTimeout(showTimer);
    };

    var cancelHide = function () {
        window.clearTimeout(hideTimer);
        hidePending = false;
    };

    var removeDescribedBy = function (link) {
        if (!link) {
            return;
        }
        var tokens = (link.getAttribute('aria-describedby') || '')
            .split(/\s+/)
            .filter(function (token) { return token && token !== 'xref-preview'; });
        if (tokens.length) {
            link.setAttribute('aria-describedby', tokens.join(' '));
        } else {
            link.removeAttribute('aria-describedby');
        }
    };

    var addDescribedBy = function (link) {
        var value = (link.getAttribute('aria-describedby') || '').trim();
        var tokens = value ? value.split(/\s+/) : [];
        if (tokens.indexOf('xref-preview') === -1) {
            tokens.push('xref-preview');
        }
        link.setAttribute('aria-describedby', tokens.join(' '));
    };

    var hide = function () {
        cancelShow();
        cancelHide();
        removeDescribedBy(currentLink);
        currentLink = null;
        if (popover) {
            popover.style.display = 'none';
        }
    };

    var distanceToPopover = function (event) {
        if (!popover || popover.style.display === 'none' || !event ||
            typeof event.clientX !== 'number') {
            return 0;
        }
        var box = popover.getBoundingClientRect();
        var dx = Math.max(box.left - event.clientX, 0, event.clientX - box.right);
        var dy = Math.max(box.top - event.clientY, 0, event.clientY - box.bottom);
        return Math.sqrt(dx * dx + dy * dy);
    };

    function scheduleHide(event) {
        window.clearTimeout(hideTimer);
        distanceAtLeave = distanceToPopover(event);
        hidePending = true;
        hideTimer = window.setTimeout(
            hide,
            HIDE_DELAY_MS + Math.min(distanceAtLeave / TRAVEL_SPEED_PX_PER_MS, MAX_TRAVEL_MS)
        );
    }

    var element = function () {
        if (!popover) {
            popover = document.createElement('div');
            popover.id = 'xref-preview';
            popover.className = 'xref-preview';
            popover.setAttribute('role', 'tooltip');
            popover.addEventListener('mouseenter', cancelHide);
            popover.addEventListener('mouseleave', scheduleHide);
            document.body.appendChild(popover);
        }
        return popover;
    };

    var targetOf = function (link) {
        var href = link.getAttribute('href') || '';
        if (href.length < 2 || href.charAt(0) !== '#') {
            return null;
        }
        var id;
        try {
            id = decodeURIComponent(href.slice(1));
        } catch (error) {
            return null;
        }
        return document.getElementById(id);
    };

    var cleanClone = function (source) {
        var clone = source.cloneNode(true);
        // Every id in the document is already spoken for by the original. A copy carrying the
        // same ones would shadow them for getElementById and for the browser's own fragment
        // navigation, so the preview would start answering for the text it is quoting.
        clone.removeAttribute('id');
        clone.querySelectorAll('[id]').forEach(function (node) {
            node.removeAttribute('id');
        });
        // A footnote marker is removed outright rather than unwrapped like the links below: its
        // visible text is the bare number, so unwrapping would strand a "[1]" that numbers
        // nothing and leads nowhere.
        clone.querySelectorAll(
            'sup.footnote, a.footnote, script, style, iframe, form, button, input, .anchor'
        ).forEach(function (node) {
            node.remove();
        });
        // Links are unwrapped, not removed: their text is ordinary prose the reader still needs.
        // They must not stay links, though — a tooltip is not a place to start navigating from,
        // and a focusable copy would put stops on the tab route that lead nowhere.
        clone.querySelectorAll('a').forEach(function (link) {
            var parent = link.parentNode;
            while (link.firstChild) {
                parent.insertBefore(link.firstChild, link);
            }
            parent.removeChild(link);
        });
        // A cell lifted out of its table has no table to be a cell of, and renders at the mercy
        // of the anonymous box the browser invents for it. Carry its children in a plain div.
        if (/^(TD|TH|LI)$/.test(clone.tagName)) {
            var box = document.createElement('div');
            while (clone.firstChild) {
                box.appendChild(clone.firstChild);
            }
            clone = box;
        }
        return clone;
    };

    var firstContentOfSection = function (heading) {
        var section = heading.closest(SECTION_SELECTOR);
        if (!section) {
            return null;
        }
        var candidates = section.querySelectorAll(CONTENT_SELECTOR);
        for (var index = 0; index < candidates.length; index += 1) {
            var candidate = candidates[index];
            if (candidate.closest(SECTION_SELECTOR) === section && candidate.textContent.trim()) {
                // A section that opens with a table is answered by the table. Reached this way
                // the candidate is its first cell, which is one square of that answer and reads
                // as a stray fragment: "5.14. English" over "English.AmericanSpelling".
                return candidate.closest('table.tableblock') || candidate;
            }
        }
        return null;
    };

    // A section holding nothing but subsections has no prose of its own to quote, and quoting a
    // subsection's opening would answer for a section the reader did not ask about. What such a
    // section does have is its shape, so the preview lists what it holds. Only the subsections
    // one level down: the deeper ones belong to those, and the list would stop being a summary.
    var contentsOfSection = function (heading) {
        var section = heading.closest(SECTION_SELECTOR);
        if (!section) {
            return null;
        }
        // Asciidoctor wraps a level-1 section's children in a .sectionbody and nests deeper
        // sections directly, so the subsections sit under one or the other.
        var body = section.querySelector(':scope > .sectionbody') || section;
        var list = document.createElement('ul');
        list.className = 'xref-preview__contents xref-preview__block';
        Array.prototype.forEach.call(body.children, function (child) {
            if (!child.matches(SECTION_SELECTOR)) {
                return;
            }
            var title = child.querySelector('h1, h2, h3, h4, h5, h6');
            if (!title) {
                return;
            }
            var item = document.createElement('li');
            item.textContent = title.textContent.trim();
            list.appendChild(item);
        });
        return list.firstChild ? list : null;
    };

    var inlineContentOf = function (target) {
        // A table is tried before the paragraph: Asciidoctor wraps cell text in a <p>, so the
        // nearest paragraph to an anchor inside a table is an artifact of the renderer, and
        // previewing it would clip the cell to its first line.
        //
        // The whole row is quoted, not the cell the anchor sits in. A row is one record and a
        // cell is one field of it, so an anchor on the field that names the record - the gate
        // identifier, the key, the term - answers with the name the reader already read and
        // withholds the definition they followed the link for. The definition is the rest of
        // the row.
        var cell = target.closest('td, th');
        if (cell && cell.textContent.trim()) {
            var row = cell.closest('tr');
            return row && row.textContent.trim() ? row : cell;
        }
        var container = target.closest('p, li, dd, dt, pre, figcaption');
        if (container && container.textContent.trim()) {
            return container;
        }
        if (target.textContent.trim()) {
            return target;
        }
        // An empty anchor placed on its own line by a block attribute belongs to whatever
        // follows it, which is where the definition the reader came for actually is.
        var following = target.nextElementSibling;
        return following && following.textContent.trim() ? following : null;
    };

    // A label is a title the author set in bold rather than in a heading: the whole block is
    // emphasised, it names a thing instead of asserting one, and it is short enough to be read
    // as a caption. Bold used for stress inside a sentence leaves unemphasised text behind and
    // fails the comparison, which is what keeps this off ordinary prose.
    var isLabel = function (block) {
        var text = block.textContent.trim();
        if (!text || text.length > LABEL_MAX_CHARS || LABEL_PATTERN.test(text)) {
            return false;
        }
        var emphasised = '';
        Array.prototype.forEach.call(block.children, function (child) {
            if (child.tagName === 'STRONG' || child.tagName === 'B') {
                emphasised += child.textContent;
            }
        });
        return emphasised.trim() === text;
    };

    // A block promising something and stopping short of delivering it answers nothing on its own
    // and sends the reader to the page anyway, so what completes it comes along. Two shapes
    // promise: a colon — "declares:", "the built-in defaults are the following:" — which the
    // list or table it announces completes, and a label — "Purpose", "Worked example" — which
    // the prose beneath it completes.
    var continuationOf = function (block) {
        var selector;
        if (isLabel(block)) {
            selector = LABEL_CONTINUATION_SELECTOR;
        } else if (LEAD_IN_PATTERN.test(block.textContent)) {
            selector = CONTINUATION_SELECTOR;
        } else {
            return null;
        }
        // Asciidoctor puts a standalone paragraph in a wrapper div and a list-item paragraph
        // directly in the <li>, so what follows the promise is a sibling of one or the other.
        var candidate = block.nextElementSibling ||
            (block.parentElement ? block.parentElement.nextElementSibling : null);
        return candidate && candidate.matches(selector) ? candidate : null;
    };

    // Only a label defers twice. It names a thing, and what it names may open with a lead-in of
    // its own — "Worked example" over "the configuration is the following:" over the YAML that
    // answers both. A lead-in announces one structure and is finished once that structure is in
    // hand, so a chain starting at one ends after a single step, as it always has.
    var continuationsOf = function (block) {
        var chain = [];
        var current = block;
        while (chain.length < MAX_CONTINUATIONS) {
            var next = continuationOf(current);
            if (!next) {
                break;
            }
            chain.push(next);
            if (!isLabel(current)) {
                break;
            }
            current = next;
        }
        return chain;
    };

    // No engine lays out a <tr> outside a table, so a quoted row is rehoused in a table of its
    // own before it is appended. The preview's existing table rules then style it, which is what
    // makes a quoted row and a quoted table look alike.
    var housed = function (clone, source) {
        if (clone.tagName !== 'TR') {
            return clone;
        }
        var table = document.createElement('table');
        // The column widths live in the source table's colgroup. A row rehoused without it is
        // laid out in equal columns, which matches neither the document nor the proportions the
        // reader just looked at.
        var origin = source.closest('table');
        var colgroup = origin && origin.querySelector(':scope > colgroup');
        if (colgroup) {
            table.appendChild(cleanClone(colgroup));
        }
        var body = document.createElement('tbody');
        body.appendChild(clone);
        table.appendChild(body);
        return table;
    };

    var appendBlock = function (wrapper, source) {
        var clone = housed(cleanClone(source), source);
        clone.classList.add('xref-preview__block');
        wrapper.appendChild(clone);
    };

    var contentOf = function (link) {
        var target = targetOf(link);
        if (!target) {
            return null;
        }
        var wrapper = document.createElement('div');
        var block;
        if (/^H[1-6]$/.test(target.tagName)) {
            var title = document.createElement('div');
            title.className = 'xref-preview__title xref-preview__block';
            // The heading's own anchor icon is an empty link, so its text is the title alone.
            title.textContent = target.textContent.trim();
            wrapper.appendChild(title);
            block = firstContentOfSection(target);
            if (!block) {
                var contents = contentsOfSection(target);
                if (contents) {
                    wrapper.appendChild(contents);
                }
            }
        } else {
            block = inlineContentOf(target);
        }
        if (block) {
            appendBlock(wrapper, block);
            continuationsOf(block).forEach(function (continuation) {
                appendBlock(wrapper, continuation);
            });
        }
        return wrapper.textContent.trim() ? wrapper : null;
    };

    var preferredWidthPx = function () {
        var root = parseFloat(window.getComputedStyle(document.documentElement).fontSize);
        return PREFERRED_WIDTH_REM * (root || 16);
    };

    // An internal link sits mid-sentence, so the lines around it are the context the reader is
    // holding while they look. Preferred placement is the margin beside the text column, where
    // nothing is covered at all; where the window is too narrow for that, below the link, and
    // above it only when there is no room below.
    var place = function (link, pop) {
        var anchor = link.getBoundingClientRect();
        // The margin starts at the right edge of the content column, not of the link's own
        // block: an indented block sits inside the column, and a preview pinned to its edge
        // would still overlap prose belonging to the column.
        var content = document.getElementById('content');
        var columnRight = content ? content.getBoundingClientRect().right : anchor.right;
        // clientWidth, not innerWidth: the latter counts the scrollbar, which would let the
        // preview sit under it.
        var viewportWidth = document.documentElement.clientWidth;
        var viewportHeight = window.innerHeight;
        var margin = viewportWidth - columnRight - 2 * GAP_PX;
        var minSideWidth = pop.querySelector(RIGID_CONTENT_SELECTOR)
            ? SIDE_MIN_WIDTH_RIGID_PX
            : SIDE_MIN_WIDTH_PX;
        var left;
        var top;

        if (margin >= minSideWidth) {
            pop.style.width = Math.min(margin, SIDE_MAX_WIDTH_PX) + 'px';
            left = columnRight + GAP_PX;
            top = anchor.top + anchor.height / 2 - pop.offsetHeight / 2;   // centred on the link
            top = Math.min(
                Math.max(GAP_PX, top),
                Math.max(GAP_PX, viewportHeight - pop.offsetHeight - GAP_PX)
            );
        } else {
            // Both gaps are spent here, so the box can always be placed at one of them and
            // still clear the other, however narrow the window gets.
            pop.style.width = Math.min(preferredWidthPx(), viewportWidth - 2 * GAP_PX) + 'px';
            left = Math.min(
                Math.max(GAP_PX, anchor.left),
                Math.max(GAP_PX, viewportWidth - pop.offsetWidth - GAP_PX)
            );
            var fitsBelow = viewportHeight - anchor.bottom >= pop.offsetHeight + GAP_PX;
            top = fitsBelow ? anchor.bottom + 8 : anchor.top - pop.offsetHeight - 8;
            top = Math.max(GAP_PX, top);
        }

        pop.style.left = (left + window.pageXOffset) + 'px';
        pop.style.top = (top + window.pageYOffset) + 'px';
    };

    var show = function (link) {
        cancelShow();
        cancelHide();
        var content = contentOf(link);
        if (!content) {
            hide();
            return;
        }
        removeDescribedBy(currentLink);
        currentLink = link;
        addDescribedBy(link);
        var pop = element();
        pop.innerHTML = '';
        pop.appendChild(content);
        pop.style.visibility = 'hidden';
        pop.style.display = 'block';
        place(link, pop);
        pop.style.visibility = 'visible';
    };

    // What is left out, and why. The anchor icon beside a heading points at the heading it sits
    // on, so its preview would quote the text already under the pointer. Footnote markers and
    // the notes they lead to have their own preview, and two of them firing on one marker would
    // fight over the same corner of the screen. Contents entries are a map of the document, read
    // as a list; a preview opening over the next entry down would obstruct that reading. Links
    // inside an open preview would let one preview replace the one it is standing in. A link to
    // an id that is not in the document has nothing to show, and is left as an ordinary link.
    var isEligible = function (link) {
        var href = link.getAttribute('href') || '';
        return href.charAt(0) === '#' && href.length > 1 &&
            !link.classList.contains('anchor') &&
            !link.classList.contains('footnote') &&
            !link.closest('#toc, #tocbot, #footnotes, .footnotes, .xref-preview') &&
            href.indexOf('#_footnotedef_') !== 0 &&
            href.indexOf('#_footnoteref_') !== 0 &&
            targetOf(link) !== null;
    };

    // Clicking a link focuses it too, but that reader is already on their way to the target and
    // a preview of where they are going only lands on top of it. Only a keyboard arrival needs
    // one. Browsers without :focus-visible reject the selector, and keep the plainer behaviour.
    var arrivedByKeyboard = function (link) {
        try {
            return link.matches(':focus-visible');
        } catch (error) {
            return true;
        }
    };

    var bind = function (link) {
        link.addEventListener('mouseenter', function () {
            cancelShow();
            cancelHide();
            showTimer = window.setTimeout(function () { show(link); }, SHOW_DELAY_MS);
        });
        link.addEventListener('mouseleave', function (event) {
            cancelShow();
            scheduleHide(event);
        });
        link.addEventListener('focus', function () {
            if (arrivedByKeyboard(link)) {
                show(link);
            }
        });
        link.addEventListener('blur', hide);
    };

    // Asciidoctor emits the footnotes block after this one, so at parse time the end of the
    // document is not there to be queried yet. Waiting for the parse keeps which links are
    // covered a matter of isEligible rather than of where this block happens to sit.
    var init = function () {
        document.querySelectorAll('#content a[href^="#"]').forEach(function (link) {
            if (isEligible(link)) {
                bind(link);
            }
        });
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    document.addEventListener('mousemove', function (event) {
        if (hidePending && distanceToPopover(event) > distanceAtLeave + AWAY_TOLERANCE_PX) {
            hide();
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            hide();
        }
    });

    window.addEventListener('resize', hide);
})();

var oldtoc = document.getElementById('toctitle').nextElementSibling;
var newtoc = document.createElement('div');
newtoc.setAttribute('id', 'tocbot');
newtoc.setAttribute('class', 'js-toc');
oldtoc.parentNode.replaceChild(newtoc, oldtoc);
tocbot.init({
    contentSelector: '#content',
    headingSelector: 'h1, h2, h3, h4, h5, h6',
    smoothScroll: false,
    collapseDepth: 3,
    orderedList: false
});
var handleTocOnResize = function () {
    var width = window.innerWidth
        || document.documentElement.clientWidth
        || document.body.clientWidth;
    if (width < 768) {
        tocbot.refresh({
            contentSelector: '#content',
            headingSelector: 'h1, h2, h3, h4, h5, h6',
            collapseDepth: 6,
            activeLinkClass: 'ignoreactive',
            throttleTimeout: 1000,
            smoothScroll: false,
            orderedList: false
        });
    } else {
        tocbot.refresh({
            contentSelector: '#content',
            headingSelector: 'h1, h2, h3, h4, h5, h6',
            smoothScroll: false,
            collapseDepth: 3,
            orderedList: false
        });
    }
};
window.addEventListener('resize', handleTocOnResize);
handleTocOnResize();
