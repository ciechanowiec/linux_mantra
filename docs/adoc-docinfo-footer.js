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
