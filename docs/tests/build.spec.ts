import { mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import {
  ASCIIDOCTOR_STYLESHEET,
  buildSite,
  FONT_STYLESHEET,
  FOOTER_SCRIPT,
  STYLESHEETS,
  VENDOR,
  VENDORED_FILES,
} from '#scripts/site'

const sorted = (names: readonly string[]): readonly string[] =>
  names.toSorted((first: string, second: string): number => first.localeCompare(second))

const TOP_LEVEL: readonly string[] = sorted([...STYLESHEETS, FOOTER_SCRIPT, VENDOR])

// A stylesheet reference to another origin: an import or a url() naming a scheme, or a protocol-relative one.
const REMOTE_REFERENCE: RegExp = /(?:@import\s+|url\(\s*)["']?(?:[a-z][a-z\d+.-]*:|\/\/)(?!\/)/iu

// The faces of the font stylesheet, which the build writes with one space after each descriptor's colon.
const FACE: RegExp = /@font-face \{[^}]*\}/gu

// The value of a descriptor such as `font-weight: 600;` in one face.
const descriptorOf = (face: string, name: string): string => new RegExp(`${name}: ([^;]+);`, 'u').exec(face)?.[1] ?? ''

// The temporary directory the site is built into, created once for the specs that read the build.
const DESTINATION: string = await mkdtemp(path.join(tmpdir(), 'pages-site-'))

// A file of the built site, as bytes or as text.
const builtBytes = async (name: string): Promise<Buffer> => readFile(path.join(DESTINATION, name))

const built = async (name: string): Promise<string> => readFile(path.join(DESTINATION, name), 'utf8')

describe('the site build', (): void => {
  beforeAll(async (): Promise<void> => {
    await writeFile(path.join(DESTINATION, 'stale.txt'), 'stale')
    await buildSite(DESTINATION)
  })

  afterAll(async (): Promise<void> => {
    await rm(DESTINATION, { recursive: true, force: true })
  })

  it('writes the footer script and the stylesheets under the names the documents load, replacing stale output', async (): Promise<void> => {
    const copies: readonly boolean[] = await Promise.all(
      STYLESHEETS.map(
        async (name: string): Promise<boolean> =>
          (await built(name)) === (await readFile(path.join('src', 'styles', name), 'utf8')),
      ),
    )
    expect([sorted(await readdir(DESTINATION)), copies]).toEqual([TOP_LEVEL, STYLESHEETS.map((): boolean => true)])
  })

  it('bundles a classic script that a plain script element can run, with tocbot inside it', async (): Promise<void> => {
    const code: string = await built(FOOTER_SCRIPT)
    const lines: readonly string[] = code.split('\n')
    expect({
      wrapped: lines.some((line: string): boolean => line.startsWith('(() => {')) && code.trimEnd().endsWith('})();'),
      moduleSyntax: lines.some((line: string): boolean => line.startsWith('import ') || line.startsWith('export ')),
      readsTheGlobal: code.includes('=> tocbot)'),
      bundlesTocbot: code.includes('toc-list') && code.includes('is-collapsible'),
    }).toEqual({ wrapped: true, moduleSyntax: false, readsTheGlobal: false, bundlesTocbot: true })
  })

  it('serves each third-party file exactly as its dependency publishes it', async (): Promise<void> => {
    const same: readonly boolean[] = await Promise.all(
      VENDORED_FILES.map(async (file: { readonly source: string; readonly target: string }): Promise<boolean> => {
        const served: Buffer = await builtBytes(path.join(VENDOR, file.target))
        return served.equals(await readFile(file.source))
      }),
    )
    const asciidoctor: string = await built(path.join(VENDOR, ASCIIDOCTOR_STYLESHEET))
    expect([same.every(Boolean), asciidoctor.startsWith('/*! Asciidoctor default stylesheet')]).toEqual([true, true])
  })

  it('declares the families, weights and styles the theme sets, each naming a font file served beside it', async (): Promise<void> => {
    const css: string = await built(path.join(VENDOR, FONT_STYLESHEET))
    const declared: readonly string[] = Array.from(css.matchAll(FACE), (match: RegExpExecArray): string => match[0])
    const faces: readonly string[] = declared.map(
      (face: string): string =>
        `${descriptorOf(face, 'font-family').replaceAll("'", '')} ${descriptorOf(face, 'font-weight')} ${descriptorOf(face, 'font-style')}`,
    )
    const files: readonly string[] = Array.from(
      css.matchAll(/url\((?<file>[^)]+)\)/gu),
      (match: RegExpExecArray): string => match.groups?.['file'] ?? '',
    )
    const served: ReadonlySet<string> = new Set(await readdir(path.join(DESTINATION, VENDOR, 'fonts')))
    expect({
      faces: sorted([...new Set(faces)]),
      everyFileServed: files.length > 0 && files.every((file: string): boolean => served.has(file)),
      polishCovered: declared.some((face: string): boolean =>
        descriptorOf(face, 'unicode-range').includes('U+0100-02BA'),
      ),
    }).toEqual({
      faces: sorted([
        'Playfair Display 400 italic',
        'Playfair Display 400 normal',
        'Playfair Display 500 normal',
        'Playfair Display 600 italic',
        'Playfair Display 600 normal',
        'Playfair Display 700 normal',
        'Source Code Pro 400 normal',
        'Source Code Pro 600 normal',
        'Source Serif 4 400 italic',
        'Source Serif 4 400 normal',
        'Source Serif 4 600 normal',
        'Source Serif 4 700 normal',
      ]),
      everyFileServed: true,
      polishCovered: true,
    })
  })

  it('names no other origin in any stylesheet the site serves', async (): Promise<void> => {
    const sheets: readonly string[] = [
      ...STYLESHEETS,
      path.join(VENDOR, FONT_STYLESHEET),
      path.join(VENDOR, ASCIIDOCTOR_STYLESHEET),
      ...VENDORED_FILES.map((file: { readonly target: string }): string => path.join(VENDOR, file.target)).filter(
        (name: string): boolean => name.endsWith('.css'),
      ),
    ]
    const remote: readonly (readonly string[])[] = await Promise.all(
      sheets.map(async (name: string): Promise<readonly string[]> => {
        const text: string = await built(name)
        // Comments may cite a URL without loading it.
        const css: string = text.replaceAll(/\/\*[\s\S]*?\*\//gu, '')
        return REMOTE_REFERENCE.test(css) ? [name] : []
      }),
    )
    expect(remote.flat()).toEqual([])
  })
})

describe('the build script', (): void => {
  it('writes the directory the Pages workflow publishes', async (): Promise<void> => {
    await import('#scripts/build')
    expect(sorted(await readdir(path.resolve('target/site')))).toEqual(TOP_LEVEL)
  })
})
