import { describe, expect, it } from 'vitest'
import { previewContentOf, targetOf } from '@/xref-content'
import { render } from './support'

const DOCUMENT: string = `
  <div id="content">
    <div class="sect1">
      <h2 id="intro"><a class="anchor" href="#intro"></a>1. Intro</h2>
      <div class="sectionbody">
        <div class="paragraph"><p id="opening">Opening with <a href="#tables">a link</a>,
          a note<sup class="footnote">[<a class="footnote" href="#_footnotedef_1">1</a>]</sup> and <span id="inner">an id</span>.</p></div>
        <div class="paragraph"><p id="lead">The defaults are the following:</p></div>
        <div class="ulist"><ul><li><p id="item">first item</p></li></ul></div>
        <div class="paragraph"><p id="label"><strong>Worked example</strong></p></div>
        <div class="paragraph"><p>The configuration is the following:</p></div>
        <div class="listingblock"><div class="content"><pre>key: value</pre></div></div>
        <div class="paragraph"><p id="stressed">Some <strong>stress</strong> only.</p></div>
        <div class="paragraph"><p>Next thought.</p></div>
      </div>
    </div>
    <div class="sect1">
      <h2 id="tables">2. Tables</h2>
      <div class="sectionbody">
        <table class="tableblock"><colgroup><col style="width: 25%"><col style="width: 75%"></colgroup>
          <tbody><tr><td class="tableblock"><p class="tableblock"><a id="key"></a>Key</p></td>
          <td class="tableblock"><p class="tableblock">The definition</p></td></tr></tbody></table>
      </div>
    </div>
    <div class="sect1">
      <h2 id="parent">3. Parent</h2>
      <div class="sectionbody">
        <div class="sect2"><h3 id="child-one">3.1. Child one</h3><div class="paragraph"><p>One.</p></div></div>
        <div class="sect2"><h3 id="child-two">3.2. Child two</h3></div>
      </div>
    </div>
    <h2 id="loose">Loose heading</h2>
    <a id="empty"></a>
    <div class="paragraph"><p id="after-empty">Text after an empty anchor.</p></div>
    <ul><li id="bare-item">A bare item</li></ul>
    <span id="blank"></span>
  </div>`

const link = (href: string): HTMLAnchorElement => {
  const created: HTMLAnchorElement = document.createElement('a')
  created.setAttribute('href', href)
  return created
}

const preview = (href: string): string | undefined => {
  const link: HTMLAnchorElement = document.createElement('a')
  link.setAttribute('href', href)
  return previewContentOf(document, link)?.getHTML()
}

render(DOCUMENT)

describe('the internal-link preview content', (): void => {
  it('finds the target of an internal link and nothing for any other link', (): void => {
    expect([
      targetOf(document, link('#intro'))?.id,
      targetOf(document, link('#')),
      targetOf(document, link('https://x')),
      targetOf(document, link('#%E0%A4%A')),
    ]).toEqual(['intro', null, null, null])
  })

  it('quotes a heading with the opening of its section, without ids, links or footnote markers', (): void => {
    expect(preview('#intro')).toBe(
      '<div class="xref-preview__title xref-preview__block">1. Intro</div><p class="xref-preview__block">Opening with a link,\n          a note and <span>an id</span>.</p>',
    )
  })

  it('brings the list a lead-in announces', (): void => {
    expect(preview('#lead')).toBe(
      '<p class="xref-preview__block">The defaults are the following:</p><div class="ulist xref-preview__block"><ul><li><p>first item</p></li></ul></div>',
    )
  })

  it('brings the lead-in a label names and the block that lead-in announces', (): void => {
    expect(preview('#label')).toBe(
      '<p class="xref-preview__block"><strong>Worked example</strong></p><div class="paragraph xref-preview__block"><p>The configuration is the following:</p></div><div class="listingblock xref-preview__block"><div class="content"><pre>key: value</pre></div></div>',
    )
  })

  it('brings nothing after prose that merely stresses a word', (): void => {
    expect(preview('#stressed')).toBe('<p class="xref-preview__block">Some <strong>stress</strong> only.</p>')
  })

  it('answers a section that opens with a table with the table', (): void => {
    expect(preview('#tables')).toContain('<table class="tableblock xref-preview__block"><colgroup>')
  })

  it('quotes the whole row of an anchor in a table, rehoused with its column widths', (): void => {
    expect(preview('#key')).toBe(
      '<table class="xref-preview__block"><colgroup><col style="width: 25%"><col style="width: 75%"></colgroup><tbody><tr><td class="tableblock"><p class="tableblock">Key</p></td>\n          <td class="tableblock"><p class="tableblock">The definition</p></td></tr></tbody></table>',
    )
  })

  it('lists the subsections of a section with no prose of its own', (): void => {
    expect(preview('#parent')).toBe(
      '<div class="xref-preview__title xref-preview__block">3. Parent</div><ul class="xref-preview__contents xref-preview__block"><li>3.1. Child one</li><li>3.2. Child two</li></ul>',
    )
  })

  it('quotes a heading outside any section by its title alone', (): void => {
    expect(preview('#loose')).toBe('<div class="xref-preview__title xref-preview__block">Loose heading</div>')
  })

  it('answers an empty anchor with what follows it, and a bare list item in a plain box', (): void => {
    expect([preview('#empty'), preview('#bare-item')]).toEqual([
      '<div class="paragraph xref-preview__block"><p>Text after an empty anchor.</p></div>',
      '<div class="xref-preview__block">A bare item</div>',
    ])
  })

  it('has nothing to show for an empty target or a missing one', (): void => {
    expect([preview('#blank'), preview('#missing')]).toEqual([undefined, undefined])
  })
})
