import { describe, expect, it } from 'vitest'
import { classedElement, cssPixels, elementById, htmlElements, orElse, setText, whenParsed } from '@/dom'
import { render } from './support'

describe('the DOM helpers', (): void => {
  it('fills an element with a text, and leaves it empty for an empty one', (): void => {
    const span: HTMLElement = classedElement(document, 'span', 'one two')
    setText(span, 'words')
    const empty: HTMLElement = document.createElement('span')
    setText(empty, '')
    expect([span.outerHTML, empty.childNodes.length]).toEqual(['<span class="one two">words</span>', 0])
  })

  it('reads a number the way the or operator does', (): void => {
    expect([orElse(0, 16), orElse(Number.NaN, 16), orElse(12, 16)]).toEqual([16, 16, 12])
  })

  it('reads the pixels of a resolved length as parseFloat does', (): void => {
    expect([cssPixels('16px'), cssPixels(' 0.5px'), cssPixels('-2.25e1px'), cssPixels('')]).toEqual([
      16,
      0.5,
      -22.5,
      Number.NaN,
    ])
  })

  it('finds the first element carrying an id, as getElementById does', (): void => {
    const find: (selector: string) => HTMLElement = render('<p id="twice">first</p><p id="twice">second</p>')
    expect([elementById(document, 'twice'), elementById(document, 'missing')]).toEqual([find('p'), null])
  })

  it('keeps the HTML elements of a query', (): void => {
    render('<p>one</p><svg><g></g></svg><p>two</p>')
    expect(
      htmlElements(document.querySelectorAll('p, g')).map((found: HTMLElement): string => found.textContent),
    ).toEqual(['one', 'two'])
  })

  it('runs a task at once in a parsed document', (): void => {
    render('<p id="task">waiting</p>')
    whenParsed(document, (): void => {
      document.querySelector('#task')?.replaceChildren('ran')
    })
    expect(document.querySelector('#task')?.textContent).toBe('ran')
  })
})
