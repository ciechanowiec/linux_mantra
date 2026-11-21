import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { enableXrefPreview } from '@/xref-preview'
import { element, render } from './support'

const DOCUMENT: string = `
  <div id="toc"><a id="contents-entry" href="#target">Target</a></div>
  <div id="content">
    <p>See <a id="link" href="#target">the target</a>, <a id="described" href="#table-target" aria-describedby="hint">the table</a>,
      <a id="heading-anchor" class="anchor" href="#target"></a><a id="note" href="#_footnotedef_1">1</a>,
      <a id="dangling" href="#nowhere">nothing</a> and <a id="empty-link" href="#empty-target">empty</a>.</p>
    <p id="target">The target paragraph.</p>
    <table><tbody><tr><td><p id="table-target">A cell.</p></td></tr></tbody></table>
    <span id="hint">A hint.</span>
    <span id="empty-target"></span>
  </div>`

const popover = (): HTMLElement => element('#xref-preview')

const mouse = (type: string, target: EventTarget, clientX: number = 0): void => {
  target.dispatchEvent(new MouseEvent(type, { bubbles: false, clientX, clientY: 0 }))
}

const hover = (selector: string): void => {
  mouse('mouseenter', element(selector))
  vi.advanceTimersByTime(140)
}

render(DOCUMENT)
enableXrefPreview(document, globalThis)

describe('the internal-link preview', (): void => {
  beforeEach((): void => {
    vi.useFakeTimers()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
  })

  afterEach((): void => {
    vi.clearAllTimers()
    vi.useRealTimers()
  })

  it('opens after a short hover and quotes the target, described by the link', (): void => {
    mouse('mouseenter', element('#link'))
    vi.advanceTimersByTime(139)
    const early: number = document.querySelectorAll('#xref-preview[style*="display: block"]').length
    vi.advanceTimersByTime(1)
    expect([
      early,
      popover().className,
      popover().getAttribute('role'),
      popover().textContent,
      popover().style.display,
    ]).toEqual([0, 'xref-preview', 'tooltip', 'The target paragraph.', 'block'])
    expect(element('#link').getAttribute('aria-describedby')).toBe('xref-preview')
  })

  it('places the preview below the link, clear of the window edges, where the window leaves no margin', (): void => {
    hover('#link')
    expect([popover().style.left, popover().style.top, popover().style.visibility]).toEqual(['12px', '12px', 'visible'])
  })

  it('keeps the descriptions a link already had and gives them back when it closes', (): void => {
    hover('#described')
    const open: string | null = element('#described').getAttribute('aria-describedby')
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    expect([
      open,
      element('#described').getAttribute('aria-describedby'),
      element('#link').hasAttribute('aria-describedby'),
    ]).toEqual(['hint xref-preview', 'hint', false])
  })

  it('moves the description to the link opened last', (): void => {
    hover('#link')
    hover('#described')
    expect([element('#link').hasAttribute('aria-describedby'), popover().textContent]).toEqual([false, 'A cell.'])
  })

  it('leaves anchor icons, footnote links, contents entries and links to nothing alone', (): void => {
    hover('#link')
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    for (const selector of ['#heading-anchor', '#note', '#contents-entry', '#dangling']) {
      hover(selector)
    }
    expect(popover().style.display).toBe('none')
  })

  it('closes instead of opening for a link whose target has nothing to show', (): void => {
    hover('#link')
    element('#empty-link').focus()
    expect([popover().style.display, element('#link').hasAttribute('aria-describedby')]).toEqual(['none', false])
  })

  it('opens on keyboard focus and closes on blur', (): void => {
    element('#link').focus()
    const opened: string = popover().style.display
    element('#link').blur()
    expect([opened, popover().style.display]).toEqual(['block', 'none'])
  })

  it('cancels a pending open when the pointer leaves first', (): void => {
    hover('#link')
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    mouse('mouseenter', element('#described'))
    mouse('mouseleave', element('#described'))
    vi.advanceTimersByTime(2000)
    expect([popover().style.display, popover().textContent]).toEqual(['none', 'The target paragraph.'])
  })

  it('closes after the grace period, unless the pointer reaches the preview', (): void => {
    hover('#link')
    mouse('mouseleave', element('#link'))
    mouse('mouseenter', popover())
    vi.advanceTimersByTime(2000)
    const held: string = popover().style.display
    mouse('mouseleave', popover())
    vi.advanceTimersByTime(180)
    expect([held, popover().style.display]).toEqual(['block', 'none'])
  })

  it('closes at once when the pointer heads away', (): void => {
    hover('#link')
    mouse('mouseleave', element('#link'))
    mouse('mousemove', document, 61)
    expect(popover().style.display).toBe('none')
  })

  it('closes on resize and when another preview opens', (): void => {
    hover('#link')
    globalThis.dispatchEvent(new Event('resize'))
    const resized: string = popover().style.display
    hover('#link')
    document.dispatchEvent(new CustomEvent('adoc:preview-open', { detail: document.body }))
    expect([resized, popover().style.display]).toEqual(['none', 'none'])
  })

  it('stays open for its own announcement and for other keys', (): void => {
    hover('#link')
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab' }))
    expect(popover().style.display).toBe('block')
  })
})
