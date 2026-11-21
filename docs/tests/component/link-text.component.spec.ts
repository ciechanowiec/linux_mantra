import { describe, expect, it } from 'vitest'
import { enableLinkText } from '@/link-text'
import { element, render } from './support'

const MIXED: string = `
  <div id="content">
    <p><a id="mixed" href="https://example.com">Read <code>pnpm</code> <em>first</em> now</a></p>
    <p><a id="plain" href="https://example.com">plain words</a></p>
    <pre><a id="verbatim" href="https://example.com">in <code>pre</code></a></pre>
  </div>
  <div id="elsewhere"><a id="outside" href="https://example.com">out <code>side</code></a></div>`

describe('the link text marker', (): void => {
  it('wraps the ordinary text of a link that holds code, and nothing else', (): void => {
    render(MIXED)
    enableLinkText(document)
    expect(element('#mixed').getHTML()).toBe(
      '<span class="ad-link-text">Read </span><code>pnpm</code> <em><span class="ad-link-text">first</span></em><span class="ad-link-text"> now</span>',
    )
  })

  it('leaves links without code, links inside verbatim blocks and links outside the document regions', (): void => {
    render(MIXED)
    enableLinkText(document)
    expect([element('#plain').getHTML(), element('#verbatim').getHTML(), element('#outside').getHTML()]).toEqual([
      'plain words',
      'in <code>pre</code>',
      'out <code>side</code>',
    ])
  })

  it('wraps nothing twice when it runs again', (): void => {
    render(MIXED)
    enableLinkText(document)
    const once: string = element('#mixed').getHTML()
    enableLinkText(document)
    expect(element('#mixed').getHTML()).toBe(once)
  })
})
