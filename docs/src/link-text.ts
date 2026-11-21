import { classedElement, whenParsed } from './dom'

// A mixed link remains one anchor. Its ordinary text receives its own inline spans so the underline can stop at
// each code frame without changing wrapping, emphasis, whitespace, the destination, or the link's accessible
// name.

const LINKS: string = '#content a[href], #header a[href], #footnotes a[href]'

const LINK_TEXT_CLASS: string = 'ad-link-text'

// Every text node under a node, in document order, as a tree walker showing text would visit them.
const textsWithin = (node: Node): readonly Text[] =>
  Array.from(node.childNodes).flatMap((child: ChildNode): readonly Text[] =>
    child instanceof Text ? [child] : textsWithin(child),
  )

const isOrdinaryText = (text: Text): boolean =>
  text.textContent.trim() !== '' && !text.parentElement?.closest(`code, .${LINK_TEXT_CLASS}`)

const markLink = (root: Document, link: Element): void => {
  if (link.closest('code, pre, .source-fields') !== null || link.querySelector('code') === null) {
    return
  }
  // Collect first: walking while inserting spans would visit the moved text again. Existing spans are skipped
  // when the script runs twice.
  const texts: readonly Text[] = textsWithin(link).filter((text: Text): boolean => isOrdinaryText(text))
  for (const text of texts) {
    const span: HTMLElement = classedElement(root, 'span', LINK_TEXT_CLASS)
    text.before(span)
    span.append(text)
  }
}

/**
 * Wraps the ordinary text of every link that also holds code, once the document is parsed.
 * @param root the document whose links to mark
 */
export const enableLinkText = (root: Document): void => {
  whenParsed(root, (): void => {
    for (const link of root.querySelectorAll(LINKS)) {
      markLink(root, link)
    }
  })
}
