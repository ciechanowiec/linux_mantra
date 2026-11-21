import tocbot from 'tocbot'
import { describe, expect, it } from 'vitest'
import { enableToc, type Tocbot } from '@/toc'
import { element, render } from './support'

const DOCUMENT: string = `
  <div id="header"><div id="toc" class="toc2"><div id="toctitle">Contents</div>
    <ul class="sectlevel1"><li><a href="#one">1. One</a></li></ul></div></div>
  <div id="content">
    <h2 id="one">1. One</h2><h3 id="one-one">1.1. One one</h3><h4 id="deep">1.1.1. Deep</h4>
    <h5 id="deeper">1.1.1.1. Deeper</h5><h2 id="two">2. Two</h2>
  </div>`

const library = (): Tocbot => tocbot

const handOver = (): void => {
  enableToc(document, globalThis, library)
}

describe('the contents panel handover', (): void => {
  it('replaces the rendered contents list with the element tocbot fills', (): void => {
    render(DOCUMENT)
    enableToc(document, globalThis, library)
    expect([
      document.querySelector('#toc .sectlevel1'),
      element('#toctitle').nextElementSibling?.outerHTML.startsWith('<div id="tocbot" class="js-toc">'),
      [...document.querySelectorAll('#tocbot a.toc-link')].map((link: Element): string => link.textContent),
    ]).toEqual([null, true, ['1. One', '1.1. One one', '1.1.1. Deep', '1.1.1.1. Deeper', '2. Two']])
  })

  it('refreshes the panel when the window is resized', (): void => {
    render(DOCUMENT)
    enableToc(document, globalThis, library)
    element('#tocbot').replaceChildren()
    globalThis.dispatchEvent(new Event('resize'))
    expect(document.querySelectorAll('#tocbot a.toc-link')).toHaveLength(5)
  })

  it('stops a document without a contents panel, as the original script did', (): void => {
    render('<div id="toctitle">Contents</div>')
    expect(handOver).toThrow(TypeError)
    render('<div id="content"><h2>Title</h2></div>')
    expect(handOver).toThrow(TypeError)
  })
})
