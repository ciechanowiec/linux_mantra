import { classedElement, type View } from './dom'
import { followScroll } from './geometry'
import { type Memory, memoryOf } from './memory'

// Contents panel behaviour. Two things tocbot does not do:
//
// 1. Keep the entry for the section being read inside the panel. tocbot marks the current entry with
//    `.is-active-link` but never scrolls its own panel, so in a document with a hundred headings the marked entry
//    leaves the panel within a few sections and the reader loses their place.
//
// 2. Give each entry's number its own box. tocbot builds every link from the heading's text, so the number arrives
//    as plain text and a wrapped entry runs back under it. Wrapping the number lets the stylesheet lay the entry out
//    as number plus title, the way a heading is laid out, so every line of a wrapped entry starts in the same place.

// A leading section number: "4.", "4.1.", "3.6.4.2.". The leading space is optional and is consumed with it,
// because a book-doctype document with an empty chapter signifier puts one in front of every top-level number.
const LEADING_NUMBER: RegExp = /^\s*(?:\d+\.)+\s+/u

const wrapNumber = (root: Document, link: Element): void => {
  if (link.querySelector('.adnum') !== null) {
    return // already wrapped
  }
  const match: RegExpExecArray | null = LEADING_NUMBER.exec(link.textContent)
  if (match === null) {
    return
  }
  const title: string = link.textContent.slice(match[0].length)
  const number: HTMLElement = classedElement(root, 'span', 'adnum')
  // The trailing space collapses away inside the flex item, where the gap is drawn by the layout, but it survives
  // in the text the reader copies, which would otherwise read "3.2.Known Facts".
  number.append(`${match[0].trim()} `)
  link.replaceChildren(number, root.createTextNode(title))
}

const follow = (view: View, panel: Element): void => {
  // Below the layout breakpoint the panel is part of the page rather than a fixed column, and it has nothing of
  // its own to scroll.
  if (view.getComputedStyle(panel).position !== 'fixed') {
    return
  }
  const active: Element | null = panel.querySelector('.is-active-link')
  const change: number =
    active === null ? 0 : followScroll(panel.getBoundingClientRect(), active.getBoundingClientRect())
  if (change !== 0) {
    panel.scrollBy(0, change)
  }
}

// Whether a pass over the panel is already waiting for the next frame.
const pendingFrames: Memory<Element, boolean> = memoryOf<Element, boolean>(false)

/**
 * Keeps the marked entry of the contents panel in view and gives each entry's number a box of its own, once per
 * frame after every scroll, resize and rebuild of the panel.
 * @param root the document whose panel to follow
 * @param view the window the document is shown in
 */
export const enableContentsPanel = (root: Document, view: View): void => {
  const panel: Element | null = root.querySelector('#toc.toc2')
  if (panel === null) {
    return
  }
  // The page scroll fires far more often than the frame rate, and tocbot rewrites the panel on its own schedule;
  // both are coalesced into one pass per frame, so the panel is never measured and written in the same turn.
  const schedule = (): void => {
    if (pendingFrames.read(panel)) {
      return
    }
    pendingFrames.write(panel, true)
    view.requestAnimationFrame((): void => {
      pendingFrames.write(panel, false)
      panel.querySelectorAll('a.toc-link').forEach((link: Element): void => {
        wrapNumber(root, link)
      })
      follow(view, panel)
    })
  }
  view.addEventListener('scroll', schedule, { passive: true })
  view.addEventListener('resize', schedule)
  // tocbot moves the active class rather than firing an event, and rebuilds the list outright when it refreshes, so
  // both kinds of change are watched. The numbers this pass wraps are changes to the panel too, and the observer
  // reports them only once the pass has finished; the next pass finds every number wrapped and the entry in view,
  // so it changes nothing and the watch settles.
  const observer: MutationObserver = new MutationObserver(schedule)
  observer.observe(panel, { subtree: true, childList: true, attributes: true, attributeFilter: ['class'] })
  schedule()
}
