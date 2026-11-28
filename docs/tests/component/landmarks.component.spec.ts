import { afterEach, describe, expect, it } from 'vitest'
import { enableLandmarks } from '@/landmarks'
import { element, render } from './support'

const PAGE: string = `
  <div id="header"><h1>Title</h1>
    <div id="toc" class="toc2"><div id="toctitle">Contents</div><ul class="sectlevel1"></ul></div>
  </div>
  <div id="content"><p>Text.</p></div>
  <div id="footnotes"><div class="footnote" id="_footnotedef_1">A note.</div></div>
  <div id="footer"><div id="footer-text">Last updated</div></div>`

const landmarks = (): readonly (readonly (string | null)[])[] =>
  ['#header', '#toc', '#content', '#footnotes', '#footer'].map((selector: string): readonly (string | null)[] => [
    element(selector).getAttribute('role'),
    element(selector).getAttribute('aria-labelledby') ?? element(selector).getAttribute('aria-label'),
  ])

describe('the landmarks', (): void => {
  afterEach((): void => {
    document.documentElement.removeAttribute('lang')
  })

  it('gives every division of a rendered page its landmark role and names the contents by their title', (): void => {
    render(PAGE)
    enableLandmarks(document)
    expect(landmarks()).toEqual([
      ['banner', null],
      ['navigation', 'toctitle'],
      ['main', null],
      ['region', 'Footnotes'],
      ['contentinfo', null],
    ])
  })

  it.each([
    ['pl', 'Przypisy'],
    ['pl-PL', 'Przypisy'],
    ['PL', 'Przypisy'],
    ['en', 'Footnotes'],
    ['en-GB', 'Footnotes'],
    ['de', 'Footnotes'],
    ['', 'Footnotes'],
  ])('names the footnotes of a page declaring %j as %j', (language: string, name: string): void => {
    render(PAGE)
    document.documentElement.setAttribute('lang', language)
    enableLandmarks(document)
    expect(element('#footnotes').getAttribute('aria-label')).toBe(name)
  })

  it('skips the divisions a page lacks and leaves an untitled contents unnamed', (): void => {
    render('<div id="content"><div id="toc" class="toc"><ul></ul></div><p>Text.</p></div>')
    enableLandmarks(document)
    expect([
      element('#content').getAttribute('role'),
      element('#toc').getAttribute('role'),
      element('#toc').hasAttribute('aria-labelledby'),
    ]).toEqual(['main', 'navigation', false])
  })

  it('changes nothing when it runs again', (): void => {
    render(PAGE)
    enableLandmarks(document)
    const once: string = document.body.getHTML()
    enableLandmarks(document)
    expect(document.body.getHTML()).toBe(once)
  })
})
