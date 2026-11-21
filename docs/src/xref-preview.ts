import { cssPixels, orElse, type View, whenParsed } from './dom'
import { type Memory, memoryOf } from './memory'
import {
  AWAY_TOLERANCE_PX,
  announceOpen,
  centredTop,
  columnRight,
  distanceToPopover,
  hideDelay,
  marginBeside,
  openedPreview,
  type Placement,
  PREVIEW_OPEN_EVENT,
  pin,
  widthWithin,
} from './preview-motion'
import { previewContentOf, targetOf } from './xref-content'

// Internal-link hover preview: a cross-reference asks the reader to go elsewhere in the document to recover one
// definition, and the jump costs them the place they were holding. Show the referenced text beside the link on
// hover or keyboard focus instead, and keep it open while the pointer rests on it. Deliberately separate from the
// footnote preview: the two answer different questions - a footnote quotes a whole short note written to be read
// on its own, while this quotes a fragment of a longer document and has to decide which fragment that is. HTML
// only, like the footnote preview; the PDF and DOCX exports carry neither the behaviour nor the docinfo that would
// load it.

const SHOW_DELAY_MS: number = 140

// Prose reflows, so a narrow margin still reads. A table laid out to a fixed width and a verbatim block cannot
// reflow: squeezed into the same column they break words mid-token and lose the alignment that made them worth
// showing, which costs the reader more than the two lines the fallback placement covers. Each asks for the room it
// needs. An image reflows by scaling, but a diagram scaled into a margin is too small to read.
const SIDE_MIN_WIDTH_PX: number = 240

const SIDE_MIN_WIDTH_RIGID_PX: number = 340

const RIGID_CONTENT_SELECTOR: string = 'table, pre, img'

const SIDE_MAX_WIDTH_PX: number = 520

const PREFERRED_WIDTH_REM: number = 38

const DEFAULT_ROOT_FONT_SIZE_PX: number = 16

const GAP_PX: number = 12

// How far below or above the link a preview placed under it sits.
const NEAR_PX: number = 8

const PREVIEW_ID: string = 'xref-preview'

const INTERNAL_LINKS: string = '#content a[href^="#"]'

const LEFT_OUT_REGIONS: string = '#toc, #tocbot, #footnotes, .footnotes, .xref-preview'

interface XrefState {
  readonly popover: HTMLElement | undefined
  readonly currentLink: Element | undefined
  readonly showTimer: number | undefined
  readonly hideTimer: number | undefined
  readonly hidePending: boolean
  readonly distanceAtLeave: number
}

interface Scene {
  readonly root: Document
  readonly view: View
}

const memory: Memory<Document, XrefState> = memoryOf<Document, XrefState>({
  popover: undefined,
  currentLink: undefined,
  showTimer: undefined,
  hideTimer: undefined,
  hidePending: false,
  distanceAtLeave: 0,
})

const stateOf = (scene: Scene): XrefState => memory.read(scene.root)

const update = (scene: Scene, change: Partial<XrefState>): void => {
  memory.write(scene.root, { ...stateOf(scene), ...change })
}

const cancelShow = (scene: Scene): void => {
  scene.view.clearTimeout(stateOf(scene).showTimer)
}

const cancelHide = (scene: Scene): void => {
  scene.view.clearTimeout(stateOf(scene).hideTimer)
  update(scene, { hidePending: false })
}

const removeDescribedBy = (link: Element | undefined): void => {
  if (link === undefined) {
    return
  }
  const tokens: readonly string[] = (link.getAttribute('aria-describedby') ?? '')
    .split(/\s+/u)
    .filter((part: string): boolean => part !== '' && part !== PREVIEW_ID)
  if (tokens.length === 0) {
    link.removeAttribute('aria-describedby')
    return
  }
  link.setAttribute('aria-describedby', tokens.join(' '))
}

const addDescribedBy = (link: Element): void => {
  const value: string = (link.getAttribute('aria-describedby') ?? '').trim()
  const tokens: readonly string[] = value === '' ? [] : value.split(/\s+/u)
  link.setAttribute('aria-describedby', (tokens.includes(PREVIEW_ID) ? tokens : [...tokens, PREVIEW_ID]).join(' '))
}

const hide = (scene: Scene): void => {
  cancelShow(scene)
  cancelHide(scene)
  removeDescribedBy(stateOf(scene).currentLink)
  update(scene, { currentLink: undefined })
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
  const popover: HTMLElement = scene.root.createElement('div')
  popover.setAttribute('id', PREVIEW_ID)
  popover.setAttribute('class', 'xref-preview')
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

const preferredWidthPx = (scene: Scene): number =>
  PREFERRED_WIDTH_REM *
  orElse(cssPixels(scene.view.getComputedStyle(scene.root.documentElement).fontSize), DEFAULT_ROOT_FONT_SIZE_PX)

// Both gaps are spent here, so the box can always be placed at one of them and still clear the other, however
// narrow the window gets.
const belowLink = (scene: Scene, anchor: DOMRect, popover: HTMLElement, viewportWidth: number): Placement => {
  const width: number = Math.min(preferredWidthPx(scene), widthWithin(viewportWidth, GAP_PX))
  popover.style.setProperty('width', `${String(width)}px`)
  const left: number = Math.min(
    Math.max(GAP_PX, anchor.left),
    Math.max(GAP_PX, viewportWidth - popover.offsetWidth - GAP_PX),
  )
  const isFitsBelow: boolean = scene.view.innerHeight - anchor.bottom >= popover.offsetHeight + GAP_PX
  const top: number = isFitsBelow ? anchor.bottom + NEAR_PX : anchor.top - popover.offsetHeight - NEAR_PX
  return { left, top: Math.max(GAP_PX, top) }
}

// An internal link sits mid-sentence, so the lines around it are the context the reader is holding while they
// look. Preferred placement is the margin beside the text column, where nothing is covered at all; where the window
// is too narrow for that, below the link, and above it only when there is no room below.
const place = (scene: Scene, link: Element, popover: HTMLElement): Placement => {
  const anchor: DOMRect = link.getBoundingClientRect()
  const right: number = columnRight(scene.root, anchor)
  // clientWidth, not innerWidth: the latter counts the scrollbar, which would let the preview sit under it.
  const viewportWidth: number = scene.root.documentElement.clientWidth
  const margin: number = marginBeside(viewportWidth, right, GAP_PX)
  const minSideWidth: number =
    popover.querySelector(RIGID_CONTENT_SELECTOR) === null ? SIDE_MIN_WIDTH_PX : SIDE_MIN_WIDTH_RIGID_PX
  if (margin < minSideWidth) {
    return belowLink(scene, anchor, popover, viewportWidth)
  }
  popover.style.setProperty('width', `${String(Math.min(margin, SIDE_MAX_WIDTH_PX))}px`)
  // Centred on the link.
  return { left: right + GAP_PX, top: centredTop(anchor, popover.offsetHeight, scene.view.innerHeight, GAP_PX) }
}

const show = (scene: Scene, link: Element): void => {
  cancelShow(scene)
  cancelHide(scene)
  const content: HTMLElement | null = previewContentOf(scene.root, link)
  if (content === null) {
    hide(scene)
    return
  }
  removeDescribedBy(stateOf(scene).currentLink)
  update(scene, { currentLink: link })
  addDescribedBy(link)
  const popover: HTMLElement = element(scene)
  popover.replaceChildren(content)
  popover.style.setProperty('visibility', 'hidden')
  popover.style.setProperty('display', 'block')
  pin(scene.view, popover, place(scene, link, popover))
  popover.style.setProperty('visibility', 'visible')
  announceOpen(scene.root, popover)
}

const isFootnoteHref = (href: string): boolean => href.startsWith('#_footnotedef_') || href.startsWith('#_footnoteref_')

// What is left out, and why. The anchor icon beside a heading points at the heading it sits on, so its preview
// would quote the text already under the pointer. Footnote markers and the notes they lead to have their own
// preview, and two of them firing on one marker would fight over the same corner of the screen. Contents entries
// are a map of the document, read as a list; a preview opening over the next entry down would obstruct that
// reading. Links inside an open preview would let one preview replace the one it is standing in. A link to an id
// that is not in the document has nothing to show, and is left as an ordinary link.
const isLeftOut = (link: Element, href: string): boolean =>
  link.classList.contains('anchor') ||
  link.classList.contains('footnote') ||
  link.closest(LEFT_OUT_REGIONS) !== null ||
  isFootnoteHref(href)

const isEligible = (root: Document, link: Element): boolean => {
  const href: string = link.getAttribute('href') ?? ''
  return href.startsWith('#') && href.length > 1 && !isLeftOut(link, href) && targetOf(root, link) !== null
}

// Clicking a link focuses it too, but that reader is already on their way to the target and a preview of where
// they are going only lands on top of it. Only a keyboard arrival needs one. Browsers without :focus-visible reject
// the selector, and keep the plainer behaviour.
const isKeyboardArrival = (link: Element): boolean => {
  try {
    return link.matches(':focus-visible')
  } catch {
    return true
  }
}

const bind = (scene: Scene, link: Element): void => {
  link.addEventListener('mouseenter', (): void => {
    cancelShow(scene)
    cancelHide(scene)
    const showTimer: number = scene.view.setTimeout((): void => {
      show(scene, link)
    }, SHOW_DELAY_MS)
    update(scene, { showTimer })
  })
  link.addEventListener('mouseleave', (event: Event): void => {
    cancelShow(scene)
    scheduleHide(scene, event)
  })
  link.addEventListener('focus', (): void => {
    if (isKeyboardArrival(link)) {
      show(scene, link)
    }
  })
  link.addEventListener('blur', (): void => {
    hide(scene)
  })
}

/**
 * Previews what each internal link of the content points at, on hover and on keyboard focus.
 * @param root the document whose links to preview
 * @param view the window the document is shown in
 */
export const enableXrefPreview = (root: Document, view: View): void => {
  const scene: Scene = { root, view }
  // Asciidoctor emits the footnotes block after the footer script, so at parse time the end of the document is not
  // there to be queried yet. Waiting for the parse keeps which links are covered a matter of isEligible rather than
  // of where the script happens to sit.
  whenParsed(root, (): void => {
    for (const link of root.querySelectorAll(INTERNAL_LINKS)) {
      if (isEligible(root, link)) {
        bind(scene, link)
      }
    }
  })
  root.addEventListener('mousemove', (event: MouseEvent): void => {
    const state: XrefState = stateOf(scene)
    if (state.hidePending && distanceToPopover(state.popover, event) > state.distanceAtLeave + AWAY_TOLERANCE_PX) {
      hide(scene)
    }
  })
  root.addEventListener(PREVIEW_OPEN_EVENT, (event: Event): void => {
    if (openedPreview(event) !== stateOf(scene).popover) {
      hide(scene)
    }
  })
  root.addEventListener('keydown', (event: KeyboardEvent): void => {
    if (event.key === 'Escape') {
      hide(scene)
    }
  })
  view.addEventListener('resize', (): void => {
    hide(scene)
  })
}
