import { describe, expect, it } from 'vitest'
import { enableContentsPanel } from '@/contents-panel'
import { element, render } from './support'

const PANEL: string = `
  <div id="toc" class="toc2" style="position: fixed">
    <div id="tocbot"><ul class="toc-list">
      <li><a class="toc-link is-active-link" href="#one">1. One</a></li>
      <li><a class="toc-link" href="#plain">Plain</a></li>
    </ul></div>
  </div>`

const nextFrame = async (): Promise<void> =>
  new Promise((resolve: () => void): void => {
    requestAnimationFrame((): void => {
      resolve()
    })
  })

describe('the contents panel', (): void => {
  it('gives each entry number a box of its own within a frame, keeping a copyable space', async (): Promise<void> => {
    render(PANEL)
    enableContentsPanel(document, globalThis)
    await nextFrame()
    expect([element('a[href="#one"]').getHTML(), element('a[href="#plain"]').getHTML()]).toEqual([
      '<span class="adnum">1. </span>One',
      'Plain',
    ])
  })

  it('wraps the entries tocbot rebuilds', async (): Promise<void> => {
    render(PANEL)
    enableContentsPanel(document, globalThis)
    await nextFrame()
    element('#tocbot').insertAdjacentHTML('beforeend', '<a class="toc-link" href="#two">2.1. Two</a>')
    await nextFrame()
    await nextFrame()
    expect(element('a[href="#two"]').getHTML()).toBe('<span class="adnum">2.1. </span>Two')
  })

  it('leaves the panel scrolled where it is while the marked entry is in view', async (): Promise<void> => {
    render(PANEL)
    enableContentsPanel(document, globalThis)
    globalThis.dispatchEvent(new Event('scroll'))
    globalThis.dispatchEvent(new Event('resize'))
    await nextFrame()
    expect(element('#toc').scrollTop).toBe(0)
  })

  it('does nothing in a document without a fixed contents panel', async (): Promise<void> => {
    render('<div id="toc"><a class="toc-link" href="#one">1. One</a></div>')
    enableContentsPanel(document, globalThis)
    await nextFrame()
    expect(element('a.toc-link').getHTML()).toBe('1. One')
  })
})
