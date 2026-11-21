import { cssPixels, htmlElements, setStyle, type View } from './dom'
import { autofitStyle } from './geometry'

// Autofit wide verbatim blocks: shrink each <pre> whose content overflows its box just enough to fit, so wide
// ASCII diagrams and code render whole instead of wrapping. Mirrors the autofit applied on the PDF side. Below
// the block's minimum scale the text stays at its normal size and wraps as before.
//
// The floor is per-block, because the two cases differ: in a multi-line block every line matters and wrapping
// would break the alignment, so heavy shrinking is worth it. A single-line block is usually a prose sentence
// that reads fine once wrapped, so shrinking it to a tiny size (as a long one-liner would force) looks worse
// than just letting it wrap at full size - such blocks only get a gentle nudge to avoid an awkward wrap, and
// otherwise wrap normally.

const VERBATIM_BLOCKS: string = '.literalblock pre, .listingblock pre'

const autofit = (root: Document, view: View, pre: HTMLElement): void => {
  pre.style.removeProperty('font-size')
  pre.style.setProperty('white-space', 'pre') // unwrap to measure the true width
  // Compare the text itself with the content box. The pre's own scrollWidth is not enough: a source block
  // wraps its text in a block-level <code>, and an overflow narrower than the pre's right padding lands inside
  // that padding, so scrollWidth still equals clientWidth while the restored pre-wrap breaks the line.
  const style: CSSStyleDeclaration = view.getComputedStyle(pre)
  const available: number = pre.clientWidth - cssPixels(style.paddingLeft) - cssPixels(style.paddingRight)
  const range: Range = root.createRange()
  range.selectNodeContents(pre)
  const fitted: { readonly whiteSpace: string; readonly fontSize: string } = autofitStyle(
    { available, natural: range.getBoundingClientRect().width, text: pre.textContent },
    cssPixels(style.fontSize),
  )
  // A block that fits, or is too wide to fit, keeps its default wrapping and size.
  setStyle(pre, 'white-space', fitted.whiteSpace)
  setStyle(pre, 'font-size', fitted.fontSize)
}

/**
 * Fits every wide verbatim block now and again on every resize of the window.
 * @param root the document whose blocks to fit
 * @param view the window the document is shown in
 */
export const enableAutofit = (root: Document, view: View): void => {
  const autofitAll = (): void => {
    const blocks: readonly HTMLElement[] = htmlElements(root.querySelectorAll(VERBATIM_BLOCKS))
    for (const pre of blocks) {
      autofit(root, view, pre)
    }
  }
  view.addEventListener('resize', autofitAll)
  autofitAll()
}
