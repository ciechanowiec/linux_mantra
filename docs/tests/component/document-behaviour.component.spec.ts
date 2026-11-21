import { describe, expect, it } from 'vitest'
import { enableDocumentBehaviour } from '@/document-behaviour'
import { element, render } from './support'

const DOCUMENT: string = `
  <div id="content">
    <h2 id="numbered"><a class="anchor" href="#numbered"></a>3.2. Known <code>Facts</code></h2>
    <h3 id="book"><a class="anchor" href="#book"></a> 1. Chapter</h3>
    <h3 id="plain">Plain title</h3>
    <h4 id="led"><em>4.</em> Emphasised</h4>
    <p><a id="bare" href="https://example.com">bare</a> <a id="framed" href="https://example.com" target="_self">framed</a>
      <a id="blank" href="https://example.com" target="">blank</a> <a id="local" href="#numbered">local</a></p>
  </div>
  <div id="footnotes">
    <div class="footnote" id="_footnotedef_1"><a href="#_footnoteref_1">1</a>. The note text.</div>
    <div class="footnote" id="_footnotedef_2"><p><a href="#_footnoteref_2">2</a>. Nested marker.</p></div>
    <div class="footnote" id="_footnotedef_3"><a href="#_footnoteref_3">3</a><em>.</em> No text tail.</div>
  </div>`

const attributes = (id: string): readonly (string | null)[] => [
  element(id).getAttribute('target'),
  element(id).getAttribute('rel'),
]

describe('the document behaviour', (): void => {
  it('gives a heading number and its title a box each, keeping the anchor and a copyable space', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    expect([element('#numbered').getHTML(), element('#book').textContent]).toEqual([
      '<a class="anchor" href="#numbered"></a><span class="adnum">3.2. </span><span class="adtext">Known <code>Facts</code></span>',
      '1. Chapter',
    ])
  })

  it('leaves a heading without a leading number as it is', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    expect([element('#plain').getHTML(), element('#led').getHTML()]).toEqual(['Plain title', '<em>4.</em> Emphasised'])
  })

  it('wraps a footnote marker and its period in one slot', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    expect([element('#_footnotedef_1').getHTML(), element('#_footnotedef_3').getHTML()]).toEqual([
      '<span class="adfn-num"><a href="#_footnoteref_1">1</a>.</span>The note text.',
      '<span class="adfn-num"><a href="#_footnoteref_3">3</a></span><em>.</em> No text tail.',
    ])
  })

  it('leaves a marker that is not a direct child of its note', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    expect(element('#_footnotedef_2').querySelector('.adfn-num')).toBeNull()
  })

  it('opens external links in a new tab unless they name a target', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    expect([attributes('#bare'), attributes('#framed'), attributes('#blank'), attributes('#local')]).toEqual([
      ['_blank', 'noopener'],
      ['_self', null],
      ['_blank', 'noopener'],
      [null, null],
    ])
  })

  it('changes nothing when it runs again', (): void => {
    render(DOCUMENT)
    enableDocumentBehaviour(document)
    const once: string = document.body.getHTML()
    enableDocumentBehaviour(document)
    expect(document.body.getHTML()).toBe(once)
  })
})
