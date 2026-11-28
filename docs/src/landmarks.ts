import { elementById, whenParsed } from './dom'

// Asciidoctor lays a page out in plain divisions, so a screen reader finds no landmark to move between and
// accessibility checks report every line as content outside any region. Each division the converter writes is
// given the role it plays. Nothing about the page's look depends on these attributes.

/** The landmark each division of a rendered page is. */
const ROLES: readonly (readonly [id: string, role: string])[] = [
  ['header', 'banner'],
  ['toc', 'navigation'],
  ['content', 'main'],
  ['footnotes', 'region'],
  ['footer', 'contentinfo'],
]

// A region landmark needs a name, and the footnotes carry no heading to take one from, so the name is written in
// the language the page declares.
const FOOTNOTES_NAMES: ReadonlyMap<string, string> = new Map([['pl', 'Przypisy']])

const DEFAULT_FOOTNOTES_NAME: string = 'Footnotes'

// The name in the language of a `lang` value such as `pl` or `en-GB`, or in English when no other is known.
const footnotesName = (language: string): string =>
  FOOTNOTES_NAMES.get(language.toLowerCase().split('-', 1)[0] ?? '') ?? DEFAULT_FOOTNOTES_NAME

/**
 * Gives each division of a rendered page its landmark role once the document is parsed: the header a banner, the
 * contents a navigation named by its title, the content the main landmark, the footnotes a named region and the
 * footer the content information. A division the page lacks is skipped.
 * @param root the document whose divisions to mark
 */
export const enableLandmarks = (root: Document): void => {
  whenParsed(root, (): void => {
    for (const [id, role] of ROLES) {
      elementById(root, id)?.setAttribute('role', role)
    }
    if (elementById(root, 'toctitle') !== null) {
      elementById(root, 'toc')?.setAttribute('aria-labelledby', 'toctitle')
    }
    elementById(root, 'footnotes')?.setAttribute('aria-label', footnotesName(root.documentElement.lang))
  })
}
