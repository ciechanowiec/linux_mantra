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
