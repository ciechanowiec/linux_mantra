import { describe, expect, it } from 'vitest'
import { columnRight, distanceToPopover, openedPreview } from '@/preview-motion'
import { element, render } from './support'

describe('what the previews read from the page', (): void => {
  it('names the preview an open signal carries, and none for a plain event', (): void => {
    const preview: HTMLElement = document.createElement('div')
    expect([
      openedPreview(new CustomEvent('adoc:preview-open', { detail: preview })),
      openedPreview(new Event('adoc:preview-open')),
    ]).toEqual([preview, undefined])
  })

  it('measures no distance to a preview that was never opened or is closed', (): void => {
    render('<div id="closed" style="display: none"></div>')
    const pointer: MouseEvent = new MouseEvent('mousemove', { clientX: 500, clientY: 500 })
    expect([distanceToPopover(undefined, pointer), distanceToPopover(element('#closed'), pointer)]).toEqual([0, 0])
  })

  it('takes the anchor edge for the column of a document without a content element', (): void => {
    render('<p id="anchor">text</p>')
    const anchor: DOMRect = new DOMRect(10, 20, 30, 40)
    expect(columnRight(document, anchor)).toBe(40)
  })
})
