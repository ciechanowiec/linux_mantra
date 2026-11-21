import { mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { describe, expect, it } from 'vitest'
import { buildSite, FOOTER_SCRIPT, STYLESHEETS } from '#scripts/site'

const sorted = (names: readonly string[]): readonly string[] =>
  names.toSorted((first: string, second: string): number => first.localeCompare(second))

describe('the site build', (): void => {
  it('writes the footer script and the stylesheets under the names the documents load, replacing stale output', async (): Promise<void> => {
    const destination: string = await mkdtemp(path.join(tmpdir(), 'pages-site-'))
    try {
      await writeFile(path.join(destination, 'stale.txt'), 'stale')
      await buildSite(destination)
      const copies: readonly boolean[] = await Promise.all(
        STYLESHEETS.map(
          async (name: string): Promise<boolean> =>
            (await readFile(path.join(destination, name), 'utf8')) ===
            (await readFile(path.join('src', 'styles', name), 'utf8')),
        ),
      )
      expect([sorted(await readdir(destination)), copies]).toEqual([
        sorted(['adoc-css-style.css', 'adoc-docinfo-footer.js', 'adoc-docinfo.css']),
        [true, true],
      ])
    } finally {
      await rm(destination, { recursive: true, force: true })
    }
  })

  it('bundles a classic script that a plain script element can run', async (): Promise<void> => {
    const destination: string = await mkdtemp(path.join(tmpdir(), 'pages-site-'))
    try {
      await buildSite(destination)
      const code: string = await readFile(path.join(destination, FOOTER_SCRIPT), 'utf8')
      const lines: readonly string[] = code.split('\n')
      expect({
        wrapped: lines.some((line: string): boolean => line.startsWith('(() => {')) && code.trimEnd().endsWith('})();'),
        moduleSyntax: lines.some((line: string): boolean => line.startsWith('import ') || line.startsWith('export ')),
        readsTheGlobal: code.includes('=> tocbot'),
      }).toEqual({ wrapped: true, moduleSyntax: false, readsTheGlobal: true })
    } finally {
      await rm(destination, { recursive: true, force: true })
    }
  })

  it('writes the directory the Pages workflow publishes through the build script', async (): Promise<void> => {
    await import('#scripts/build')
    expect(sorted(await readdir(path.resolve('target/site')))).toEqual(
      sorted(['adoc-css-style.css', 'adoc-docinfo-footer.js', 'adoc-docinfo.css']),
    )
  })
})
