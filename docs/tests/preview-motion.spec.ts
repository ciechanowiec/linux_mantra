import { describe, expect, it } from 'vitest'
import { distanceToBox } from '@/geometry'
import { centredTop, hideDelay, marginBeside, widthWithin } from '@/preview-motion'

const BOX: { left: number; top: number; right: number; bottom: number } = {
  left: 100,
  top: 100,
  right: 200,
  bottom: 150,
}

describe('the geometry the previews share', (): void => {
  it('measures no distance to a point inside the box', (): void => {
    expect(distanceToBox(BOX, 150, 120)).toBe(0)
  })

  it('measures the straight distance to the nearest corner', (): void => {
    expect(distanceToBox(BOX, 230, 190)).toBe(50)
  })

  it('waits the grace period for a pointer already at the preview', (): void => {
    expect(hideDelay(0)).toBe(180)
  })

  it('budgets the journey at an unhurried pointer speed', (): void => {
    expect(hideDelay(400)).toBe(680)
  })

  it('caps the journey so a preview never hangs open', (): void => {
    expect(hideDelay(10_000)).toBe(1580)
  })

  it('centres a preview on its anchor', (): void => {
    expect(centredTop({ top: 300, height: 20 }, 100, 900, 12)).toBe(260)
  })

  it('keeps a centred preview clear of the top and bottom edges', (): void => {
    expect([
      centredTop({ top: 0, height: 20 }, 100, 900, 12),
      centredTop({ top: 880, height: 20 }, 100, 900, 12),
    ]).toEqual([12, 788])
  })

  it('gives the margin beside the column after a gap on either side', (): void => {
    expect(marginBeside(1400, 900, 12)).toBe(476)
  })

  it('gives the viewport width after a gap at either edge', (): void => {
    expect(widthWithin(800, 12)).toBe(776)
  })
})
