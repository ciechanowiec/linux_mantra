import { elementById, orElse, type View } from './dom'

// The contents panel is rebuilt by tocbot, which the published documents load from a CDN right before the footer
// script: Asciidoctor's own list is replaced by an empty element tocbot fills and keeps current while the reader
// scrolls. Below the layout breakpoint the panel is part of the page rather than a fixed column, so there it lists
// every level and leaves no entry marked as the active one.

const NARROW_WINDOW_PX: number = 768

const WIDE_COLLAPSE_DEPTH: number = 3

const NARROW_COLLAPSE_DEPTH: number = 6

const NARROW_THROTTLE_MS: number = 1000

/** The options the footer script hands tocbot, exactly as the original script wrote them. */
interface TocOptions {
  readonly contentSelector: string
  readonly headingSelector: string
  readonly smoothScroll: boolean
  readonly collapseDepth: number
  readonly orderedList: boolean
  readonly activeLinkClass?: string
  readonly throttleTimeout?: number
}

/** The two calls of tocbot the footer script makes. */
export interface Tocbot {
  readonly init: (options: TocOptions) => void
  readonly refresh: (options: TocOptions) => void
}

const wideOptions = (): TocOptions => ({
  contentSelector: '#content',
  headingSelector: 'h1, h2, h3, h4, h5, h6',
  smoothScroll: false,
  collapseDepth: WIDE_COLLAPSE_DEPTH,
  orderedList: false,
})

const narrowOptions = (): TocOptions => ({
  contentSelector: '#content',
  headingSelector: 'h1, h2, h3, h4, h5, h6',
  collapseDepth: NARROW_COLLAPSE_DEPTH,
  activeLinkClass: 'ignoreactive',
  throttleTimeout: NARROW_THROTTLE_MS,
  smoothScroll: false,
  orderedList: false,
})

const tocListOf = (root: Document): Element => {
  const list: Element | null | undefined = elementById(root, 'toctitle')?.nextElementSibling
  if (list === null || list === undefined) {
    // The original script read this element without a guard, so a document without a contents panel stopped it
    // here, before the behaviours that follow; throwing keeps that.
    throw new TypeError('The document has no contents list after #toctitle')
  }
  return list
}

/**
 * Hands the contents panel to tocbot, and refreshes it for the width of the window on every resize.
 * @param root the document whose contents panel to replace
 * @param view the window the document is shown in
 * @param library reads the tocbot the document loaded, at the moment the original script read it
 * @throws {TypeError} when the document has no contents list
 */
export const enableToc = (root: Document, view: View, library: () => Tocbot): void => {
  const placeholder: HTMLElement = root.createElement('div')
  const list: Element = tocListOf(root)
  placeholder.setAttribute('id', 'tocbot')
  placeholder.setAttribute('class', 'js-toc')
  list.replaceWith(placeholder)
  library().init(wideOptions())
  const handleTocOnResize = (): void => {
    const width: number = orElse(orElse(view.innerWidth, root.documentElement.clientWidth), root.body.clientWidth)
    library().refresh(width < NARROW_WINDOW_PX ? narrowOptions() : wideOptions())
  }
  view.addEventListener('resize', handleTocOnResize)
  handleTocOnResize()
}
