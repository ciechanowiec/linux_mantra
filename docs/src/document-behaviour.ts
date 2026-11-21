import { classedElement, setText, whenParsed } from './dom'

// Three things the rendered page needs that the converter does not do, and that the stylesheet cannot do on its
// own, because each one needs an element that does not exist in the markup.
//
// Everything here is idempotent: the page may be rendered once and the script may run again after tocbot rebuilds
// part of it.

// A leading section number: "4.", "4.1.", "3.6.4.2.". The leading space is optional and is consumed with it: a
// book-doctype document with an empty chapter signifier writes "</a> 1. Title", and a pattern anchored straight to
// the anchor would skip every top-level heading in such a document.
const HEADING_NUMBER: RegExp = /^\s*(?:\d+\.)+\s+/u

const FOOTNOTE_TAIL: RegExp = /^\s*\.\s*/u

const HEADINGS: string = '#content h2, #content h3, #content h4, #content h5, #content h6'

const FOOTNOTES: string = '#footnotes .footnote'

const EXTERNAL_LINKS: string = 'a[href^="http://"], a[href^="https://"]'

const headingTitleOf = (heading: Element): readonly ChildNode[] => {
  const anchor: Element | null = heading.querySelector('a.anchor')
  return Array.from(heading.childNodes).filter((node: ChildNode): boolean => !node.isSameNode(anchor))
}

// 1. The section number and the title it qualifies are laid out as two boxes on one baseline, so that every line
// of a wrapped title starts in the same place whatever the number's width. Both need an element of their own. The
// title is wrapped as well as the number: the heading is a flex container, and a flex container promotes every
// inline child to an item, so a bare title holding a code span would lay that span out as a separate block
// stretched to the heading's height.
const wrapHeading = (root: Document, heading: Element): void => {
  if (heading.querySelector('.adnum') !== null) {
    return
  }
  const rest: readonly ChildNode[] = headingTitleOf(heading)
  const [first] = rest
  const match: RegExpExecArray | null = first instanceof Text ? HEADING_NUMBER.exec(first.data) : null
  if (match === null || !(first instanceof Text)) {
    return
  }
  first.deleteData(0, match[0].length)
  const number: HTMLElement = classedElement(root, 'span', 'adnum')
  // The trailing space collapses away between flex items, where the gap is drawn by the layout, but it survives in
  // the text the reader copies, which would otherwise read "3.2.Known Facts".
  setText(number, `${match[0].trim()} `)
  const title: HTMLElement = classedElement(root, 'span', 'adtext')
  title.append(...rest)
  heading.append(number, title)
}

// 2. A footnote's marker is an anchor followed by a bare "." text node, so the note's text begins wherever that run
// happens to end: one column for a one-digit number, another for three. Wrapping the run lets the stylesheet give
// it a slot of fixed width, so every line of every note starts on the same vertical. The separating space goes
// with it, because the slot supplies the gap.
const wrapFootnoteMarker = (root: Document, note: Element): void => {
  const marker: Element | null = note.querySelector('a[href^="#_footnoteref"]')
  if (marker?.parentNode !== note || note.querySelector('.adfn-num') !== null) {
    return
  }
  const wrapper: HTMLElement = classedElement(root, 'span', 'adfn-num')
  marker.before(wrapper)
  wrapper.append(marker)
  const next: ChildNode | null = wrapper.nextSibling
  const tail: RegExpExecArray | null = next instanceof Text ? FOOTNOTE_TAIL.exec(next.data) : null
  if (tail === null || !(next instanceof Text)) {
    return
  }

  wrapper.append(root.createTextNode('.'))
  next.deleteData(0, tail[0].length)
}

// 3. A link that leaves the document opens in its own tab, as the ones written into the prose already do.
// Asciidoctor adds the attribute only where the source marks a link with `^`; a bare URL written into a sources
// record carries no such mark, so following one replaced the document the reader was in.
const detachExternalLink = (link: Element): void => {
  const target: string | null = link.getAttribute('target')
  if (target !== null && target !== '') {
    return
  }
  link.setAttribute('target', '_blank')
  link.setAttribute('rel', 'noopener')
}

/**
 * Wraps heading numbers and footnote markers in elements of their own, and opens external links in a new tab, once
 * the document is parsed.
 * @param root the document to shape
 */
export const enableDocumentBehaviour = (root: Document): void => {
  whenParsed(root, (): void => {
    for (const heading of root.querySelectorAll(HEADINGS)) {
      wrapHeading(root, heading)
    }
    for (const note of root.querySelectorAll(FOOTNOTES)) {
      wrapFootnoteMarker(root, note)
    }
    for (const link of root.querySelectorAll(EXTERNAL_LINKS)) {
      detachExternalLink(link)
    }
  })
}
