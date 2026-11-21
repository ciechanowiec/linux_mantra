import { describe, expect, it } from 'vitest'
import { enableAutofit } from '@/autofit'
import { element, render } from './support'

describe('the verbatim block autofit', (): void => {
  it('restores a block that fits to its default size and wrapping', (): void => {
    render(
      '<div class="listingblock"><pre style="font-size: 30px; white-space: pre">code</pre></div><pre id="loose">x</pre>',
    )
    enableAutofit(document, globalThis)
    expect(element('.listingblock pre').style.cssText).toBe('')
  })

  it('fits the blocks again when the window is resized', (): void => {
    render('<div class="literalblock"><pre>text</pre></div>')
    enableAutofit(document, globalThis)
    element('.literalblock pre').style.setProperty('font-size', '40px')
    globalThis.dispatchEvent(new Event('resize'))
    expect(element('.literalblock pre').style.getPropertyValue('font-size')).toBe('')
  })
})
