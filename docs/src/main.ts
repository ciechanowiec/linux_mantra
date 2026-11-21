import { enableAutofit } from './autofit'
import { enableContentsPanel } from './contents-panel'
import { enableDocumentBehaviour } from './document-behaviour'
import { enableFootnotePreview } from './footnote-preview'
import { enableLinkText } from './link-text'
import { enableToc, type Tocbot } from './toc'
import { enableXrefPreview } from './xref-preview'

// The footer script of the AsciiDoc documents that load https://www.ciechanowiec.eu/linux_mantra/
// adoc-docinfo-footer.js. The build bundles this module into that classic script. The behaviours start in the
// order the hand-written script ran them, so their listeners fire in the same order, and a document without a
// contents panel stops at the contents step exactly as it did.

// The global the documents define by loading tocbot from a CDN just before this script.
declare const tocbot: Tocbot

enableLinkText(document)
enableAutofit(document, globalThis)
enableFootnotePreview(document, globalThis)
enableXrefPreview(document, globalThis)
enableToc(document, globalThis, (): Tocbot => tocbot)
enableDocumentBehaviour(document)
enableContentsPanel(document, globalThis)
