import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { enableFootnotePreview } from '@/footnote-preview'
import { element, render } from './support'

const DOCUMENT: string = `
  <div id="content">
    <p>Claim<sup class="footnote">[<a id="_footnoteref_1" class="footnote" href="#_footnotedef_1" title="View footnote.">1</a>]</sup>
      and another<sup class="footnote">[<a id="_footnoteref_2" class="footnote" href="#_footnotedef_2" title="View footnote.">2</a>]</sup>
      and an empty one<sup class="footnote">[<a id="_footnoteref_3" class="footnote" href="#_footnotedef_3">3</a>]</sup>
      and a lost one<sup class="footnote">[<a id="_footnoteref_4" class="footnote" href="#_footnotedef_9">4</a>]</sup></p>
  </div>
  <div id="footnotes">
    <div class="footnote" id="_footnotedef_1">
<a href="#_footnoteref_1">1</a>. The source, at <a href="https://example.com">example.com</a> &amp; <code>here</code>.
</div>
    <div class="footnote" id="_footnotedef_2"><a href="#_footnoteref_2">2</a>.&nbsp;Kept no-break space. </div>
    <div class="footnote" id="_footnotedef_3"><a href="#_footnoteref_3">3</a>. </div>
  </div>`

// What the original script showed for a note: the definition's HTML without its back-reference, with the "N."
// label and the outer space trimmed off the serialized text.
const originalContent = (id: string): string => {
  const clone: Node = element(id).cloneNode(true)
  if (!(clone instanceof HTMLElement)) {
    throw new TypeError('A clone of an element is an element')
  }
  clone.querySelector('a[href^="#_footnoteref_"]')?.remove()
  return clone
    .getHTML()
    .replace(/^\s*\.\s*/u, '')
    .trim()
}

const popover = (): HTMLElement => element('.fn-pop')

const mouse = (type: string, target: EventTarget, clientX: number = 0): void => {
  target.dispatchEvent(new MouseEvent(type, { bubbles: false, clientX, clientY: 0 }))
}

render(DOCUMENT)
const expected: readonly string[] = [originalContent('#_footnotedef_1'), originalContent('#_footnotedef_2')]
enableFootnotePreview(document, globalThis)

describe('the footnote preview', (): void => {
  beforeEach((): void => {
    vi.useFakeTimers()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
  })

  afterEach((): void => {
    vi.clearAllTimers()
    vi.useRealTimers()
  })

  it('drops the native tooltip of every marker it previews', (): void => {
    expect(element('#_footnoteref_1').hasAttribute('title')).toBe(false)
  })

  it('shows the note as the original script did, without its label', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    expect([popover().getHTML(), popover().getAttribute('role'), popover().style.display]).toEqual([
      expected[0],
      'tooltip',
      'block',
    ])
  })

  it('keeps a no-break space the original script kept', (): void => {
    mouse('mouseenter', element('#_footnoteref_2'))
    expect(popover().getHTML()).toBe(expected[1])
  })

  it('places the note below its marker where the window leaves no margin, and announces it', (): void => {
    document.addEventListener('adoc:preview-open', (event: Event): void => {
      const detail: unknown = event instanceof CustomEvent ? event.detail : undefined
      if (detail instanceof HTMLElement) {
        detail.classList.add('announced')
      }
    })
    element('#_footnoteref_1').dispatchEvent(new FocusEvent('focus'))
    expect([
      popover().style.left,
      popover().style.top,
      popover().style.visibility,
      popover().classList.contains('fn-pop--side'),
    ]).toEqual(['8px', '8px', 'visible', false])
    expect(popover().classList.contains('announced')).toBe(true)
  })

  it('shows nothing for a note with no text or a marker that leads nowhere', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    mouse('mouseenter', element('#_footnoteref_3'))
    mouse('mouseenter', element('#_footnoteref_4'))
    expect(popover().style.display).toBe('none')
  })

  it('closes once the pointer has left and the grace period has passed', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    mouse('mouseleave', element('#_footnoteref_1'))
    vi.advanceTimersByTime(179)
    const during: string = popover().style.display
    vi.advanceTimersByTime(1)
    expect([during, popover().style.display]).toEqual(['block', 'none'])
  })

  it('stays open while the pointer rests on the note', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    mouse('mouseleave', element('#_footnoteref_1'))
    mouse('mouseenter', popover())
    vi.advanceTimersByTime(2000)
    expect(popover().style.display).toBe('block')
  })

  it('closes at once when the pointer heads away from the note', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    mouse('mouseleave', popover())
    mouse('mousemove', document, 59)
    const near: string = popover().style.display
    mouse('mousemove', document, 61)
    expect([near, popover().style.display]).toEqual(['block', 'none'])
  })

  it('closes on blur, on Escape, on resize and when another preview opens', (): void => {
    const closes: readonly (() => void)[] = [
      (): void => {
        element('#_footnoteref_1').dispatchEvent(new FocusEvent('blur'))
      },
      (): void => {
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
      },
      (): void => {
        globalThis.dispatchEvent(new Event('resize'))
      },
      (): void => {
        document.dispatchEvent(new CustomEvent('adoc:preview-open', { detail: document.body }))
      },
    ]
    const states: readonly string[] = closes.map((close: () => void): string => {
      mouse('mouseenter', element('#_footnoteref_1'))
      close()
      return popover().style.display
    })
    expect(states).toEqual(['none', 'none', 'none', 'none'])
  })

  it('ignores other keys', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }))
    expect(popover().style.display).toBe('block')
  })

  it('reads no distance from a leave that carries no pointer position', (): void => {
    mouse('mouseenter', element('#_footnoteref_1'))
    element('#_footnoteref_1').dispatchEvent(new Event('mouseleave'))
    vi.advanceTimersByTime(180)
    expect(popover().style.display).toBe('none')
  })
})
