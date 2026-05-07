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
