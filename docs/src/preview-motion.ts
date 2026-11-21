import { elementById, type View } from './dom'
import { distanceToBox } from './geometry'

// What the footnote preview and the internal-link preview share: how long a closing preview lingers, how far
// the pointer may stray on its way to it, and the signal one preview gives the other when it opens.

const HIDE_DELAY_MS: number = 180 // grace period once the pointer is already at the preview

const TRAVEL_SPEED_PX_PER_MS: number = 0.8 // an unhurried pointer, not a flick

const MAX_TRAVEL_MS: number = 1400 // a stuck-open preview is worse than a lost one

/** Absorbs the wobble of an imprecise but honest approach. */
export const AWAY_TOLERANCE_PX: number = 60

/**
 * Each preview replaces only itself, and a closing one deliberately lingers while the pointer may still be
 * travelling to it, so without a shared signal the two would stack. The one opened last is the one asked for.
 */
export const PREVIEW_OPEN_EVENT: string = 'adoc:preview-open'

/**
 * The distance from the pointer to an open preview, zero when there is no open preview to travel to.
 * @param popover the preview, if one was ever opened
 * @param event the event that left the preview or its anchor, which carries no distance unless it is a pointer event
 * @returns the distance in pixels
 */
export const distanceToPopover = (popover: HTMLElement | undefined, event: Event): number =>
  popover === undefined || popover.style.display === 'none' || !(event instanceof MouseEvent)
    ? 0
    : distanceToBox(popover.getBoundingClientRect(), event.clientX, event.clientY)

/**
 * How long a preview waits before it closes once the pointer has left. A preview can sit a full column away from
 * what opened it, so a delay tuned for an adjacent preview would expire mid-journey: the wait budgets for the gap
 * the pointer actually has to cross. Budgeting that generously would leave the preview hanging whenever the reader
 * isn't heading for it, so a companion mousemove watcher cuts the wait short as soon as the pointer commits to
 * going elsewhere.
 * @param distance the distance the pointer has to cross to reach the preview
 * @returns the delay in milliseconds
 */
export const hideDelay = (distance: number): number =>
  HIDE_DELAY_MS + Math.min(distance / TRAVEL_SPEED_PX_PER_MS, MAX_TRAVEL_MS)

const carriesDetail = (event: Event): event is CustomEvent<unknown> => event instanceof CustomEvent

/**
 * The preview an open signal announces.
 * @param event the signal
 * @returns the preview that opened, if the signal names one
 */
export const openedPreview = (event: Event): unknown => (carriesDetail(event) ? event.detail : undefined)

/**
 * Tells every other preview of the document that this one opened.
 * @param root the document
 * @param popover the preview that opened
 */
export const announceOpen = (root: Document, popover: HTMLElement): void => {
  root.dispatchEvent(new CustomEvent(PREVIEW_OPEN_EVENT, { detail: popover }))
}

/** Where a preview goes, in coordinates of the viewport. */
export interface Placement {
  readonly left: number
  readonly top: number
}

/**
 * Pins a placed preview to the document, so it scrolls with the text it belongs to.
 * @param view the window the document is shown in
 * @param popover the preview
 * @param placement where it goes in the viewport
 */
export const pin = (view: View, popover: HTMLElement, placement: Placement): void => {
  popover.style.setProperty('left', `${String(placement.left + view.scrollX)}px`)
  popover.style.setProperty('top', `${String(placement.top + view.scrollY)}px`)
}

/** The vertical extent of a box on the screen, as a DOMRect gives it. */
export interface VerticalSpan {
  readonly top: number
  readonly height: number
}

const HALVES: number = 2

/**
 * Keeps a box of a given height, centred on an anchor, inside the viewport with a gap at either edge.
 * @param anchor the box the preview is centred on
 * @param height the height of the preview
 * @param viewportHeight the height of the viewport
 * @param gap the gap kept at the top and the bottom edge
 * @returns the top of the preview, in viewport coordinates
 */
export const centredTop = (anchor: VerticalSpan, height: number, viewportHeight: number, gap: number): number => {
  const top: number = anchor.top + anchor.height / HALVES - height / HALVES
  return Math.min(Math.max(gap, top), Math.max(gap, viewportHeight - height - gap))
}

/**
 * The right edge of the content column. The margin starts there rather than at the right edge of the block the
 * anchor sits in: an indented block (an admonition, a nested list) sits inside the column, and a preview pinned to
 * its edge would still overlap prose belonging to the column.
 * @param root the document
 * @param anchor the box of what opened the preview, whose edge stands in where the document has no column
 * @returns the right edge, in viewport coordinates
 */
export const columnRight = (root: Document, anchor: DOMRect): number => {
  const content: Element | null = elementById(root, 'content')
  return content ? content.getBoundingClientRect().right : anchor.right
}

const BOTH_SIDES: number = 2

/**
 * The width a preview may take in the margin beside the content column, once it keeps a gap on either side.
 * @param viewportWidth the width of the viewport
 * @param right the right edge of the content column
 * @param gap the gap kept on each side of the preview
 * @returns the width in pixels, negative where the column leaves no margin
 */
export const marginBeside = (viewportWidth: number, right: number, gap: number): number =>
  viewportWidth - right - BOTH_SIDES * gap

/**
 * The width of the viewport once a gap is kept at either edge.
 * @param viewportWidth the width of the viewport
 * @param gap the gap kept at each edge
 * @returns the width in pixels
 */
export const widthWithin = (viewportWidth: number, gap: number): number => viewportWidth - BOTH_SIDES * gap
