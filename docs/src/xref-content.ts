import { classedElement, elementById, setText } from './dom'

// Which fragment of the document an internal link previews. A footnote quotes a whole short note written to be
// read on its own, while an internal link quotes a fragment of a longer document and has to decide which fragment
// that is.

const SECTION_SELECTOR: string = '.sect0, .sect1, .sect2, .sect3, .sect4, .sect5'

// A colon ends an announcement, not an answer.
const LEAD_IN_PATTERN: RegExp = /:\s*$/u

// A bold run standing alone announces the same way a colon does: "Purpose", "Worked example" name what comes next
// instead of saying it. Sentence-ending punctuation marks a statement, and length marks prose that merely happens
// to be emphasised, so both rule the label out.
const LABEL_PATTERN: RegExp = /[.!?:\u{2026}]\s*$/u

const LABEL_MAX_CHARS: number = 60

// What a colon may introduce. Deliberately not a paragraph: prose following prose is the next thought, not the
// completion of the previous one, and pulling it in doubles the preview for no gain.
const CONTINUATION_SELECTOR: string = [
  '.olist',
  '.ulist',
  '.dlist',
  '.listingblock',
  '.literalblock',
  '.admonitionblock',
  '.exampleblock',
  'table.tableblock',
].join(', ')

// What a label may introduce, which is anything a colon may plus the prose the colon rule declines: a label is a
// heading in all but markup, so the paragraph under it is not the next thought, it is the only thought there is.
const LABEL_CONTINUATION_SELECTOR: string = `${CONTINUATION_SELECTOR}, .paragraph`

// A label may introduce a lead-in, which in turn introduces a list or a block. Two hops reach the end of that
// chain; a third would be quoting the section rather than sampling it.
const MAX_CONTINUATIONS: number = 2

const CONTENT_SELECTOR: string = [
  '.paragraph > p',
  '.olist > ol > li > p',
  '.ulist > ul > li > p',
  '.dlist dd > p',
  '.admonitionblock td.content',
  '.listingblock pre',
  '.literalblock pre',
  'table.tableblock p',
  '.imageblock',
].join(', ')

const BLOCK_CLASS: string = 'xref-preview__block'

// A fragment link names at least one character after its hash.
const MIN_FRAGMENT_LENGTH: number = 2

const HEADING: RegExp = /^H[1-6]$/u

const UNHOUSED_CELL: RegExp = /^(?:TD|TH|LI)$/u

/**
 * The element an internal link points at, or null when the link is not internal or points at nothing.
 * @param root the document
 * @param link the link
 * @returns the target element
 */
export const targetOf = (root: Document, link: Element): Element | null => {
  const href: string = link.getAttribute('href') ?? ''
  if (href.length < MIN_FRAGMENT_LENGTH || !href.startsWith('#')) {
    return null
  }
  try {
    return elementById(root, decodeURIComponent(href.slice(1)))
  } catch {
    return null
  }
}

const cleanClone = (root: Document, source: Element): Element => {
  const clone: Element = root.importNode(source, true)
  // Every id in the document is already spoken for by the original. A copy carrying the same ones would shadow
  // them for getElementById and for the browser's own fragment navigation, so the preview would start answering
  // for the text it is quoting.
  clone.removeAttribute('id')
  clone.querySelectorAll('[id]').forEach((node: Element): void => {
    node.removeAttribute('id')
  })
  // A footnote marker is removed outright rather than unwrapped like the links below: its visible text is the
  // bare number, so unwrapping would strand a "[1]" that numbers nothing and leads nowhere.
  clone
    .querySelectorAll('sup.footnote, a.footnote, script, style, iframe, form, button, input, .anchor')
    .forEach((node: Element): void => {
      node.remove()
    })
  // Links are unwrapped, not removed: their text is ordinary prose the reader still needs. They must not stay
  // links, though - a tooltip is not a place to start navigating from, and a focusable copy would put stops on the
  // tab route that lead nowhere.
  clone.querySelectorAll('a').forEach((link: HTMLAnchorElement): void => {
    link.replaceWith(...Array.from(link.childNodes))
  })
  if (!UNHOUSED_CELL.test(clone.tagName)) {
    return clone
  }
  // A cell lifted out of its table has no table to be a cell of, and renders at the mercy of the anonymous box the
  // browser invents for it. Carry its children in a plain div.
  const box: HTMLElement = root.createElement('div')
  box.append(...Array.from(clone.childNodes))
  return box
}

const firstContentOfSection = (heading: Element): Element | null => {
  const section: Element | null = heading.closest(SECTION_SELECTOR)
  if (section === null) {
    return null
  }
  const first: Element | undefined = Array.from(section.querySelectorAll(CONTENT_SELECTOR)).find(
    (candidate: Element): boolean =>
      // An image has no text of its own, yet a section that opens with a diagram is answered by the diagram.
      candidate.closest(SECTION_SELECTOR) === section &&
      (candidate.textContent.trim() !== '' || candidate.querySelector('img') !== null),
  )
  // A section that opens with a table is answered by the table. Reached this way the candidate is its first cell,
  // which is one square of that answer and reads as a stray fragment: "5.14. English" over
  // "English.AmericanSpelling".
  return first === undefined ? null : (first.closest('table.tableblock') ?? first)
}

// A section holding nothing but subsections has no prose of its own to quote, and quoting a subsection's opening
// would answer for a section the reader did not ask about. What such a section does have is its shape, so the
// preview lists what it holds. Only the subsections one level down: the deeper ones belong to those, and the list
// would stop being a summary.
const contentsOfSection = (root: Document, heading: Element): Element | null => {
  const section: Element | null = heading.closest(SECTION_SELECTOR)
  if (section === null) {
    return null
  }
  // Asciidoctor wraps a level-1 section's children in a .sectionbody and nests deeper sections directly, so the
  // subsections sit under one or the other.
  const body: Element = section.querySelector(':scope > .sectionbody') ?? section
  const items: readonly HTMLElement[] = Array.from(body.children)
    .filter((child: Element): boolean => child.matches(SECTION_SELECTOR))
    .flatMap((child: Element): readonly HTMLElement[] => {
      const title: Element | null = child.querySelector('h1, h2, h3, h4, h5, h6')
      if (title === null) {
        return []
      }
      const item: HTMLElement = root.createElement('li')
      setText(item, title.textContent.trim())
      return [item]
    })
  if (items.length === 0) {
    return null
  }
  const list: HTMLElement = classedElement(root, 'ul', `xref-preview__contents ${BLOCK_CLASS}`)
  list.append(...items)
  return list
}

// An element with text of its own, or null for one with none or for no element at all.
const withText = (element: Element | null): Element | null =>
  element === null || element.textContent.trim() === '' ? null : element

const inlineContentOf = (target: Element): Element | null => {
  // A table is tried before the paragraph: Asciidoctor wraps cell text in a <p>, so the nearest paragraph to an
  // anchor inside a table is an artifact of the renderer, and previewing it would clip the cell to its first line.
  //
  // The whole row is quoted, not the cell the anchor sits in. A row is one record and a cell is one field of it,
  // so an anchor on the field that names the record - the gate identifier, the key, the term - answers with the
  // name the reader already read and withholds the definition they followed the link for. The definition is the
  // rest of the row.
  const cell: Element | null = withText(target.closest('td, th'))
  if (cell !== null) {
    return withText(cell.closest('tr')) ?? cell
  }
  // An empty anchor placed on its own line by a block attribute belongs to whatever follows it, which is where the
  // definition the reader came for actually is.
  return (
    withText(target.closest('p, li, dd, dt, pre, figcaption')) ??
    withText(target) ??
    withText(target.nextElementSibling)
  )
}

// A label is a title the author set in bold rather than in a heading: the whole block is emphasised, it names a
// thing instead of asserting one, and it is short enough to be read as a caption. Bold used for stress inside a
// sentence leaves unemphasised text behind and fails the comparison, which is what keeps this off ordinary prose.
const isLabel = (block: Element): boolean => {
  const text: string = block.textContent.trim()
  if (text === '' || text.length > LABEL_MAX_CHARS || LABEL_PATTERN.test(text)) {
    return false
  }
  const emphasised: string = Array.from(block.children)
    .filter((child: Element): boolean => child.tagName === 'STRONG' || child.tagName === 'B')
    .map((child: Element): string => child.textContent)
    .join('')
  return emphasised.trim() === text
}

const promiseSelector = (block: Element): string | undefined => {
  if (isLabel(block)) {
    return LABEL_CONTINUATION_SELECTOR
  }
  return LEAD_IN_PATTERN.test(block.textContent) ? CONTINUATION_SELECTOR : undefined
}

// A block promising something and stopping short of delivering it answers nothing on its own and sends the reader
// to the page anyway, so what completes it comes along. Two shapes promise: a colon - "declares:", "the built-in
// defaults are the following:" - which the list or table it announces completes, and a label - "Purpose", "Worked
// example" - which the prose beneath it completes.
const continuationOf = (block: Element): Element | null => {
  const selector: string | undefined = promiseSelector(block)
  if (selector === undefined) {
    return null
  }
  // Asciidoctor puts a standalone paragraph in a wrapper div and a list-item paragraph directly in the <li>, so
  // what follows the promise is a sibling of one or the other.
  const candidate: Element | null = block.nextElementSibling ?? block.parentElement?.nextElementSibling ?? null
  return candidate?.matches(selector) === true ? candidate : null
}

// Only a label defers twice. It names a thing, and what it names may open with a lead-in of its own - "Worked
// example" over "the configuration is the following:" over the YAML that answers both. A lead-in announces one
// structure and is finished once that structure is in hand, so a chain starting at one ends after a single step,
// as it always has.
const continuationsOf = (block: Element, room: number = MAX_CONTINUATIONS): readonly Element[] => {
  const next: Element | null = room > 0 ? continuationOf(block) : null
  if (next === null) {
    return []
  }
  return isLabel(block) ? [next, ...continuationsOf(next, room - 1)] : [next]
}

// No engine lays out a <tr> outside a table, so a quoted row is rehoused in a table of its own before it is
// appended. The preview's existing table rules then style it, which is what makes a quoted row and a quoted table
// look alike.
const housed = (root: Document, clone: Element, source: Element): Element => {
  if (clone.tagName !== 'TR') {
    return clone
  }
  const table: HTMLElement = root.createElement('table')
  // The column widths live in the source table's colgroup. A row rehoused without it is laid out in equal
  // columns, which matches neither the document nor the proportions the reader just looked at.
  const colgroup: Element | null | undefined = source.closest('table')?.querySelector(':scope > colgroup')
  if (colgroup) {
    table.append(cleanClone(root, colgroup))
  }
  const body: HTMLElement = root.createElement('tbody')
  body.append(clone)
  table.append(body)
  return table
}

const appendBlock = (root: Document, wrapper: Element, source: Element): void => {
  const clone: Element = housed(root, cleanClone(root, source), source)
  clone.classList.add(BLOCK_CLASS)
  wrapper.append(clone)
}

const headingContent = (root: Document, wrapper: Element, heading: Element): Element | null => {
  const title: HTMLElement = classedElement(root, 'div', `xref-preview__title ${BLOCK_CLASS}`)
  // The heading's own anchor icon is an empty link, so its text is the title alone.
  setText(title, heading.textContent.trim())
  wrapper.append(title)
  const block: Element | null = firstContentOfSection(heading)
  const contents: Element | null = block === null ? contentsOfSection(root, heading) : null
  if (contents !== null) {
    wrapper.append(contents)
  }
  return block
}

/**
 * The preview of what an internal link points at: the heading and the opening of its section, or the passage an
 * anchor sits in, each with whatever completes it.
 * @param root the document
 * @param link the link to preview
 * @returns the preview's content, or null when the link has nothing to show
 */
export const previewContentOf = (root: Document, link: Element): HTMLElement | null => {
  const target: Element | null = targetOf(root, link)
  if (target === null) {
    return null
  }
  const wrapper: HTMLElement = root.createElement('div')
  const block: Element | null = HEADING.test(target.tagName)
    ? headingContent(root, wrapper, target)
    : inlineContentOf(target)
  if (block !== null) {
    appendBlock(root, wrapper, block)
    for (const continuation of continuationsOf(block)) {
      appendBlock(root, wrapper, continuation)
    }
  }
  return wrapper.textContent.trim() === '' ? null : wrapper
}
