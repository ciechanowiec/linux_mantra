/**
 * The element a selector finds in the document.
 * @param selector the selector
 * @returns the element, which must exist and be an HTML element
 */
export const element = (selector: string): HTMLElement => {
  const found: Element | null = document.querySelector(selector)
  if (!(found instanceof HTMLElement)) {
    throw new TypeError(`No element matches ${selector}`)
  }
  return found
}

/**
 * Replaces the body with the markup given and returns the element a selector finds in it.
 * @param markup the body's new content
 * @returns a finder for elements of the body, which fails when nothing matches
 */
export const render = (markup: string): ((selector: string) => HTMLElement) => {
  document.body.replaceChildren()
  document.body.insertAdjacentHTML('beforeend', markup)
  return element
}
