// The arithmetic of the footer script, kept apart from the page it measures: how far a pointer is from a
// preview, how much a verbatim block shrinks to fit, and how far the contents panel scrolls to follow the reader.

/** The edges of a box on the screen, as a DOMRect gives them. */
export interface Edges {
  readonly left: number
  readonly top: number
  readonly right: number
  readonly bottom: number
}

/**
 * The distance from a point to the nearest point of a box, zero inside it.
 * @param box the box
 * @param pointerX the horizontal coordinate of the point
 * @param pointerY the vertical coordinate of the point
 * @returns the distance in pixels
 */
export const distanceToBox = (box: Edges, pointerX: number, pointerY: number): number =>
  Math.hypot(
    Math.max(box.left - pointerX, 0, pointerX - box.right),
    Math.max(box.top - pointerY, 0, pointerY - box.bottom),
  )

const MIN_SCALE_MULTILINE: number = 0.55

const MIN_SCALE_SINGLELINE: number = 0.85

// The font size is set a touch below the exact fit, so the block lands inside its box rather than on its edge.
const FIT_FACTOR: number = 0.98

// Text made of nothing but line breaks.
const ONLY_BREAKS: RegExp = /^\n*$/u

/** What a verbatim block measured once its text was unwrapped. */
interface VerbatimMeasure {
  /** The width of the block's content box. */
  readonly available: number
  /** The width the unwrapped text takes. */
  readonly natural: number
  /** The text of the block. */
  readonly text: string
}

/**
 * The scale that fits a block's text to its box, or nothing where the block keeps its size: because the text
 * already fits, or because fitting it would shrink the text below the block's floor.
 * @param measure what the block measured
 * @returns the scale to apply, if any
 */
const autofitScale = (measure: VerbatimMeasure): number | undefined => {
  const scale: number = measure.natural > 0 ? measure.available / measure.natural : 1
  // One line of text, however many line breaks end it.
  const firstBreak: number = measure.text.indexOf('\n')
  const isSingleLine: boolean = firstBreak === -1 || ONLY_BREAKS.test(measure.text.slice(firstBreak))
  const minScale: number = isSingleLine ? MIN_SCALE_SINGLELINE : MIN_SCALE_MULTILINE
  return scale >= 1 || scale < minScale ? undefined : scale
}

/**
 * The font size that applies a scale to a block's current size.
 * @param base the block's font size in pixels
 * @param scale the scale that fits it
 * @returns the scaled font size, in pixels
 */
const fittedFontSize = (base: number, scale: number): number => base * scale * FIT_FACTOR

/** The inline style a verbatim block keeps after the autofit, an empty value meaning none. */
interface VerbatimStyle {
  readonly whiteSpace: string
  readonly fontSize: string
}

/**
 * The inline style that fits a block: unwrapped at a smaller size where a scale fits it, and otherwise back to its
 * default size and wrapping.
 * @param measure what the block measured
 * @param base the block's font size in pixels
 * @returns the white-space and font-size values to set, an empty one to remove
 */
export const autofitStyle = (measure: VerbatimMeasure, base: number): VerbatimStyle => {
  const scale: number | undefined = autofitScale(measure)
  return scale === undefined
    ? { whiteSpace: '', fontSize: '' }
    : { whiteSpace: 'pre', fontSize: `${String(fittedFontSize(base, scale))}px` }
}

// Space kept between the marked entry and the panel edge, so the entries around it stay visible and the reader
// keeps the context of where they are.
const EDGE_MARGIN_PX: number = 96

// At most a third of the panel's height is kept clear at either edge, so a short panel still has room to follow.
const EDGE_SHARE: number = 3

/** The vertical edges of a box on the screen, as a DOMRect gives them. */
interface VerticalEdges {
  readonly top: number
  readonly bottom: number
  readonly height: number
}

/**
 * How far the panel scrolls to keep its marked entry clear of either edge, zero when it already is.
 * @param panel the box of the panel
 * @param active the box of the marked entry
 * @returns the change to the panel's scroll position, in pixels
 */
export const followScroll = (panel: VerticalEdges, active: VerticalEdges): number => {
  const margin: number = Math.min(EDGE_MARGIN_PX, panel.height / EDGE_SHARE)
  if (active.top < panel.top + margin) {
    return active.top - panel.top - margin
  }
  return active.bottom > panel.bottom - margin ? active.bottom - panel.bottom + margin : 0
}
