import tocbot from 'tocbot'
import { enableAutofit } from './autofit'
import { enableContentsPanel } from './contents-panel'
import { enableDocumentBehaviour } from './document-behaviour'
import { enableFootnotePreview } from './footnote-preview'
import { enableLandmarks } from './landmarks'
import { enableLinkText } from './link-text'
import { enableToc, type Tocbot } from './toc'
import { enableXrefPreview } from './xref-preview'

// The footer script of the AsciiDoc documents that load https://www.ciechanowiec.eu/linux_mantra/
// adoc-docinfo-footer.js. The build bundles this module into that classic script. The behaviours start in the
// order the hand-written script ran them, so their listeners fire in the same order, and a document without a
// contents panel stops at the contents step exactly as it did. The landmarks come first, so that stop cannot
// leave a page without them.
//
// tocbot is bundled with the script rather than read from the global a CDN copy defines, so a document needs no
// script from another origin. A document that still loads that copy defines a global this script ignores.

enableLandmarks(document)
enableLinkText(document)
enableAutofit(document, globalThis)
enableFootnotePreview(document, globalThis)
enableXrefPreview(document, globalThis)
enableToc(document, globalThis, (): Tocbot => tocbot)
enableDocumentBehaviour(document)
enableContentsPanel(document, globalThis)
