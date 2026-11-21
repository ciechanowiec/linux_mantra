import { describe, expect, it } from 'vitest'
import { autofitStyle } from '@/geometry'

const DEFAULT: { whiteSpace: string; fontSize: string } = { whiteSpace: '', fontSize: '' }

describe('the style that fits a verbatim block', (): void => {
  it('gives a block whose text already fits back its default wrapping and size', (): void => {
    expect(autofitStyle({ available: 500, natural: 400, text: 'a\nb' }, 16)).toEqual(DEFAULT)
  })

  it('leaves a block with no measurable text alone', (): void => {
    expect(autofitStyle({ available: 500, natural: 0, text: '' }, 16)).toEqual(DEFAULT)
  })

  it('shrinks a multi-line block a touch below the exact fit, keeping it unwrapped', (): void => {
    expect(autofitStyle({ available: 300, natural: 500, text: 'first\nsecond' }, 20)).toEqual({
      whiteSpace: 'pre',
      fontSize: `${String(20 * (300 / 500) * 0.98)}px`,
    })
  })

  it('lets a multi-line block wrap below its floor', (): void => {
    expect(autofitStyle({ available: 250, natural: 500, text: 'first\nsecond' }, 16)).toEqual(DEFAULT)
  })

  it('holds a block with trailing line breaks to the gentler single-line floor', (): void => {
    expect([
      autofitStyle({ available: 450, natural: 500, text: 'one line\n\n' }, 10).whiteSpace,
      autofitStyle({ available: 400, natural: 500, text: 'one line\n\n' }, 10).whiteSpace,
    ]).toEqual(['pre', ''])
  })
})
