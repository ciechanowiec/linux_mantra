import { readFile } from 'node:fs/promises'
import { describe, expect, it } from 'vitest'
import { element } from './support'

// The whole footer script over a real Asciidoctor rendering, with the tocbot it bundles and no global copy.
describe('the footer script over a rendered document', (): void => {
  it('applies every behaviour of the original script', async (): Promise<void> => {
    document.body.insertAdjacentHTML('beforeend', await readFile('tests/fixtures/rendered-document.txt', 'utf8'))
    await import('@/main')
    const firstHeading: HTMLElement = element('#content h2')
    expect({
      heading: firstHeading.querySelector('.adnum')?.textContent,
      tocbot: document.querySelector('#tocbot a.toc-link')?.textContent,
      footnoteSlots: document.querySelectorAll('#footnotes .footnote > .adfn-num').length,
      externalTargets: [...document.querySelectorAll('a[href^="https://"]')].every(
        (link: Element): boolean => link.getAttribute('target') === '_blank',
      ),
      mixedLinkText: document.querySelectorAll('#content a .ad-link-text').length > 0,
      markerTitles: document.querySelectorAll('a.footnote[title]').length,
      landmarks: ['#header', '#toc', '#content', '#footnotes', '#footer'].map(
        (selector: string): string | null | undefined => document.querySelector(selector)?.getAttribute('role'),
      ),
    }).toEqual({
      heading: '1. ',
      tocbot: '1. First Section with code in the Title',
      footnoteSlots: 3,
      externalTargets: true,
      mixedLinkText: true,
      markerTitles: 0,
      landmarks: ['banner', 'navigation', 'main', 'region', 'contentinfo'],
    })
  })
})
