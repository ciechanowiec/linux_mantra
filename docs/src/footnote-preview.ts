import { classedElement, elementById, type View } from './dom'
import type { Edges } from './geometry'
import { type Memory, memoryOf } from './memory'
import {
  AWAY_TOLERANCE_PX,
  announceOpen,
  centredBeside,
  centredTop,
  distanceToPopover,
  hideDelay,
  openedPreview,
  type Placement,
  PREVIEW_OPEN_EVENT,
  pin,
  roomBeside,
  textRight,
} from './preview-motion'

// Footnote hover preview: a footnote carries the citation for the statement it hangs off, so following one
// otherwise costs a jump to the foot of the page and the reader's place. Show the note's own content beside the
// reference on hover or keyboard focus, and keep it open while the pointer rests on it so any links inside stay
// reachable. HTML only: the PDF renders real footnotes at the foot of the page, and the DOCX export loads no
// docinfo.

// A footnote marker sits at the end of the claim it cites, and prose wraps, so the claim occupies the marker's own
// line and the lines above it. Placing the note above therefore hides the very text the reader opened it to check.
// Preferred placement is the margin beside the text column, where nothing is covered at all; where the window is
// too narrow for that, below the marker, which at worst covers the *next* sentence.
const SIDE_MIN_WIDTH_PX: number = 240 // narrower than this a margin note reads as a ransom note

const SIDE_MAX_WIDTH_PX: number = 380

const GAP_PX: number = 12

// How far below or above the marker a note placed under it sits, and how far it keeps from the window's edges.
const NEAR_PX: number = 8

const SIDE_CLASS: string = 'fn-pop--side'

const MARKERS: string = 'a.footnote[href^="#_footnotedef_"]'

// Whitespace as a serialized note reads it. The original script trimmed the note's HTML, where a no-break space
// is written as an entity and so is never trimmed; reading the nodes, the no-break space is left alone too.
const isTrimmedSpace = (char: string | undefined): boolean =>
  char !== undefined && char !== '\u{A0}' && char.trim() === ''

// The index of the first character at or after a position that is not trimmed space.
const pastSpace = (text: string, at: number): number => (isTrimmedSpace(text[at]) ? pastSpace(text, at + 1) : at)

// The index just past the last character before a position that is not trimmed space.
const beforeSpace = (text: string, at: number): number =>
  at > 0 && isTrimmedSpace(text[at - 1]) ? beforeSpace(text, at - 1) : at

// How much of a note's opening text is the "N." label's tail and the space around it: the space, a period and the
// space after it, or, without a period, only the space.
const leadInLength = (text: string): number => {
  const start: number = pastSpace(text, 0)
  return text[start] === '.' ? pastSpace(text, start + 1) : start
}

interface FootnoteState {
  readonly popover: HTMLElement | undefined
  readonly hideTimer: number | undefined
  /** The mousemove watcher only arbitrates a hide already scheduled. */
  readonly hidePending: boolean
  readonly distanceAtLeave: number
}

interface Scene {
  readonly root: Document
  readonly view: View
}

const memory: Memory<Document, FootnoteState> = memoryOf<Document, FootnoteState>({
  popover: undefined,
  hideTimer: undefined,
  hidePending: false,
  distanceAtLeave: 0,
})

const stateOf = (scene: Scene): FootnoteState => memory.read(scene.root)

const update = (scene: Scene, change: Partial<FootnoteState>): void => {
  memory.write(scene.root, { ...stateOf(scene), ...change })
}

const cancelHide = (scene: Scene): void => {
  scene.view.clearTimeout(stateOf(scene).hideTimer)
  update(scene, { hidePending: false })
}

const hide = (scene: Scene): void => {
  update(scene, { hidePending: false })
  stateOf(scene).popover?.style.setProperty('display', 'none')
}

const scheduleHide = (scene: Scene, event: Event): void => {
  scene.view.clearTimeout(stateOf(scene).hideTimer)
  const distanceAtLeave: number = distanceToPopover(stateOf(scene).popover, event)
  const hideTimer: number = scene.view.setTimeout((): void => {
    hide(scene)
  }, hideDelay(distanceAtLeave))
  update(scene, { distanceAtLeave, hidePending: true, hideTimer })
}

const element = (scene: Scene): HTMLElement => {
  const existing: HTMLElement | undefined = stateOf(scene).popover
  if (existing !== undefined) {
    return existing
  }
  const popover: HTMLElement = classedElement(scene.root, 'div', 'fn-pop')
  popover.setAttribute('role', 'tooltip')
  popover.addEventListener('mouseenter', (): void => {
    cancelHide(scene)
  })
  popover.addEventListener('mouseleave', (event: Event): void => {
    scheduleHide(scene, event)
  })
  scene.root.body.append(popover)
  update(scene, { popover })
  return popover
}

const trimStart = (node: ChildNode | null): void => {
  if (node instanceof Text) {
    node.deleteData(0, leadInLength(node.data))
  }
}

const trimEnd = (node: ChildNode | null): void => {
  if (!(node instanceof Text)) {
    return
  }

  const end: number = beforeSpace(node.data, node.data.length)
  node.deleteData(end, node.data.length - end)
}

// The definition opens with a back-reference link and an "N." label. The popover repeats neither, because the
// reader is already standing on that reference.
const contentOf = (root: Document, link: Element): readonly ChildNode[] | undefined => {
  const definition: Element | null = elementById(root, (link.getAttribute('href') ?? '').slice(1))
  if (definition === null) {
    return undefined
  }
  const clone: Element = root.importNode(definition, true)
  clone.querySelector('a[href^="#_footnoteref_"]')?.remove()
  // Adjacent text joins into one node, as it does in the HTML the note serializes to, so the label and the space
  // around the note are trimmed wherever they fall in that text.
  clone.normalize()
  trimStart(clone.firstChild)
  trimEnd(clone.lastChild)
  const nodes: readonly ChildNode[] = Array.from(clone.childNodes)
  return nodes.every((node: ChildNode): boolean => node instanceof Text && node.data === '') ? undefined : nodes
}

const belowMarker = (anchor: Edges, popover: HTMLElement, viewport: View, viewportWidth: number): Placement => {
  const isFitsBelow: boolean = viewport.innerHeight - anchor.bottom > popover.offsetHeight + GAP_PX
  return {
    left: Math.min(Math.max(NEAR_PX, anchor.left), Math.max(NEAR_PX, viewportWidth - popover.offsetWidth - NEAR_PX)),
    top: isFitsBelow ? anchor.bottom + NEAR_PX : anchor.top - popover.offsetHeight - NEAR_PX,
  }
}

const place = (scene: Scene, link: Element, popover: HTMLElement): Placement => {
  const anchor: DOMRect = link.getBoundingClientRect()
  const right: number = textRight(scene.root, scene.view, anchor)
  // clientWidth, not innerWidth: the latter counts the scrollbar, which would let the note sit under it.
  const viewportWidth: number = scene.root.documentElement.clientWidth
  const margin: number = roomBeside(viewportWidth, right)
  if (margin < SIDE_MIN_WIDTH_PX) {
    return belowMarker(anchor, popover, scene.view, viewportWidth)
  }
  popover.classList.add(SIDE_CLASS)
  popover.style.setProperty('width', `${String(Math.min(margin, SIDE_MAX_WIDTH_PX))}px`)
  // Centred on the marker, and in the margin between the text and the edge of the page.
  return {
    left: centredBeside(viewportWidth, right, popover.offsetWidth),
    top: centredTop(anchor, popover.offsetHeight, scene.view.innerHeight, GAP_PX),
  }
}

const show = (scene: Scene, link: Element): void => {
  cancelHide(scene)
  const content: readonly ChildNode[] | undefined = contentOf(scene.root, link)
  if (content === undefined) {
    return
  }
  const popover: HTMLElement = element(scene)
  popover.replaceChildren(...content)
  popover.classList.remove(SIDE_CLASS) // placement is decided fresh on every open
  popover.style.removeProperty('width')
  popover.style.setProperty('visibility', 'hidden') // measure before placing, so it never flashes
  popover.style.setProperty('display', 'block')
  pin(scene.view, popover, place(scene, link, popover))
  popover.style.setProperty('visibility', 'visible')
  announceOpen(scene.root, popover)
}

const bindMarker = (scene: Scene, link: Element): void => {
  link.removeAttribute('title') // the native "View footnote." tooltip would fight the popover
  link.addEventListener('mouseenter', (): void => {
    show(scene, link)
  })
  link.addEventListener('mouseleave', (event: Event): void => {
    scheduleHide(scene, event)
  })
  link.addEventListener('focus', (): void => {
    show(scene, link)
  })
  link.addEventListener('blur', (): void => {
    hide(scene)
  })
}

/**
 * Previews each footnote beside its marker on hover and on keyboard focus. The markers are the ones the document
 * holds when this runs.
 * @param root the document whose footnotes to preview
 * @param view the window the document is shown in
 */
export const enableFootnotePreview = (root: Document, view: View): void => {
  const scene: Scene = { root, view }
  root.addEventListener(PREVIEW_OPEN_EVENT, (event: Event): void => {
    if (openedPreview(event) !== stateOf(scene).popover) {
      hide(scene)
    }
  })
  root.addEventListener('mousemove', (event: MouseEvent): void => {
    const state: FootnoteState = stateOf(scene)
    if (state.hidePending && distanceToPopover(state.popover, event) > state.distanceAtLeave + AWAY_TOLERANCE_PX) {
      hide(scene) // committed to going elsewhere; no reason to keep waiting
    }
  })
  root.querySelectorAll(MARKERS).forEach((link: Element): void => {
    bindMarker(scene, link)
  })
  root.addEventListener('keydown', (event: KeyboardEvent): void => {
    if (event.key === 'Escape') {
      hide(scene)
    }
  })
  // Placement is measured once, at open time. A resize invalidates it - margin mode may no longer fit, and the
  // marker has moved - so drop the note rather than leave it stranded.
  view.addEventListener('resize', (): void => {
    hide(scene)
  })
}
