/**
 * Replaces the content of an element with a text, as assigning `textContent` does: an empty text leaves the
 * element with no child at all rather than with an empty text node.
 * @param element the element to fill
 * @param text the text it holds afterwards
 */
export const setText = (element: Element, text: string): void => {
  element.replaceChildren(...(text === '' ? [] : [text]))
}

/**
 * Creates an element carrying the classes given, as setting `className` on a new element does.
 * @param root the document that owns the element
 * @param tag the element's tag name
 * @param classes the value of its class attribute
 * @returns the element, not yet attached
 */
export const classedElement = (root: Document, tag: string, classes: string): HTMLElement => {
  const element: HTMLElement = root.createElement(tag)
  element.setAttribute('class', classes)
  return element
}

/**
 * Reads a number the way the `||` operator reads one, falling back on zero and on NaN.
 * @param value the number to read
 * @param fallback what to read instead of zero or NaN
 * @returns the value, or the fallback in its place
 */
export const orElse = (value: number, fallback: number): number =>
  value === 0 || Number.isNaN(value) ? fallback : value

/**
 * The HTML elements of a list of elements, which is every one of them in an HTML document.
 * @param elements the elements a query found
 * @returns those that are HTML elements, in their order
 */
export const htmlElements = (elements: ArrayLike<Element>): readonly HTMLElement[] =>
  Array.from(elements).filter((element: Element): element is HTMLElement => element instanceof HTMLElement)

/**
 * Runs a task once the document is parsed: at once when it already is, otherwise on `DOMContentLoaded`. The
 * published documents load the footer script from inside their content, before the footnotes block and the
 * footer are parsed, so a task that has to see the whole document waits for the parse.
 * @param root the document the task reads
 * @param task what to run
 */
export const whenParsed = (root: Document, task: () => void): void => {
  if (root.readyState === 'loading') {
    root.addEventListener('DOMContentLoaded', task)
  } else {
    task()
  }
}

/** What the behaviours read from, and listen to, on the window a document is shown in. */
export type View = Pick<
  Window,
  | 'addEventListener'
  | 'clearTimeout'
  | 'getComputedStyle'
  | 'innerHeight'
  | 'innerWidth'
  | 'requestAnimationFrame'
  | 'scrollX'
  | 'scrollY'
  | 'setTimeout'
>

// A number at the start of a CSS value, as parseFloat reads one: "16px" is 16, and a value with no number is NaN.
const LEADING_NUMBER: RegExp = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/iu

/**
 * Reads the number of pixels a resolved CSS length gives, such as a computed font size of "16px".
 * @param value the resolved value
 * @returns the number it opens with, or NaN when it opens with none
 */
export const cssPixels = (value: string): number => {
  const found: RegExpExecArray | null = LEADING_NUMBER.exec(value.trim())
  return found === null ? Number.NaN : Number(found[0])
}

/**
 * The first element of a document carrying an id, in tree order, as getElementById finds it.
 * @param root the document
 * @param id the id, which is never empty
 * @returns the element, or null when none carries the id
 */
export const elementById = (root: Document, id: string): Element | null => root.querySelector(`#${CSS.escape(id)}`)

/**
 * Sets an inline style property, or removes it for an empty value, as assigning the property does.
 * @param element the element whose inline style to change
 * @param property the property, in its CSS spelling
 * @param value the value, empty to remove the property
 */
export const setStyle = (element: HTMLElement, property: string, value: string): void => {
  if (value === '') {
    element.style.removeProperty(property)
  } else {
    element.style.setProperty(property, value)
  }
}
