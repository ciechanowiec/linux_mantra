import { describe, expect, it } from 'vitest'
import { followScroll } from '@/geometry'

const PANEL: { top: number; bottom: number; height: number } = { top: 0, bottom: 600, height: 600 }

describe('how far the contents panel follows its marked entry', (): void => {
  it('stays put while the entry sits clear of both edges', (): void => {
    expect(followScroll(PANEL, { top: 300, bottom: 320, height: 20 })).toBe(0)
  })

  it('scrolls up to keep the edge margin above an entry near the top', (): void => {
    expect(followScroll(PANEL, { top: 40, bottom: 60, height: 20 })).toBe(-56)
  })

  it('scrolls down to keep the edge margin below an entry near the bottom', (): void => {
    expect(followScroll(PANEL, { top: 560, bottom: 580, height: 20 })).toBe(76)
  })

  it('keeps at most a third of a short panel clear', (): void => {
    expect(followScroll({ top: 0, bottom: 150, height: 150 }, { top: 10, bottom: 30, height: 20 })).toBe(-40)
  })
})
