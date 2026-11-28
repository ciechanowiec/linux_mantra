import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const PROJECT: string = fileURLToPath(new URL('../', import.meta.url))

/** The name the published documents load the footer script by. */
export const FOOTER_SCRIPT: string = 'adoc-docinfo-footer.js'

/**
 * The stylesheets the published documents load, served under the names they have in `src/styles`. Asciidoctor
 * links `font-awesome.css` from the styles directory of a document whose header turns `iconfont-remote` off.
 */
export const STYLESHEETS: readonly string[] = ['adoc-css-style.css', 'adoc-docinfo.css', 'font-awesome.css']

/** The directory of the site the third-party files the stylesheets import are served from. */
export const VENDOR: string = 'vendor'

// The directory of a package, from the manifest or module it resolves to. Each package is resolved by a specifier
// written out in full, which is how the dependency check sees the package used.
const directoryOf = (resolved: string): string => path.dirname(fileURLToPath(resolved))

const FONT_AWESOME: string = directoryOf(import.meta.resolve('@fortawesome/fontawesome-free/package.json'))

const FONT_AWESOME_FOUR: string = directoryOf(import.meta.resolve('font-awesome/package.json'))

const PLAYFAIR_DISPLAY: string = directoryOf(import.meta.resolve('@fontsource/playfair-display/package.json'))

const SOURCE_SERIF_FOUR: string = directoryOf(import.meta.resolve('@fontsource-variable/source-serif-4/package.json'))

const SOURCE_CODE_PRO: string = directoryOf(import.meta.resolve('@fontsource/source-code-pro/package.json'))

const ASCIIDOCTOR_PACKAGE: string = '@asciidoctor/core'

// The package of Asciidoctor.js exports only its processor, so its stylesheet is found from the package root: the
// last `node_modules/@asciidoctor/core` directory on the path of the module the package resolves to.
const ASCIIDOCTOR_MODULE: string = fileURLToPath(import.meta.resolve('@asciidoctor/core'))

/** A file a dependency publishes, and where under the vendor directory the site serves it. */
interface VendoredFile {
  readonly source: string
  readonly target: string
}

// Each file keeps its place beside the files its stylesheet names relatively, such as `../webfonts/` from Font
// Awesome's `css/`.
const fontAwesome = (name: string): VendoredFile => ({
  source: path.join(FONT_AWESOME, name),
  target: `fontawesome-free/${name}`,
})

const fontAwesomeFour = (name: string): VendoredFile => ({
  source: path.join(FONT_AWESOME_FOUR, name),
  target: `font-awesome/${name}`,
})

/** The files the stylesheets import, each taken as its dependency publishes it. */
export const VENDORED_FILES: readonly VendoredFile[] = [
  fontAwesome('css/all.min.css'),
  ...['fa-brands-400', 'fa-regular-400', 'fa-solid-900', 'fa-v4compatibility'].map(
    (font: string): VendoredFile => fontAwesome(`webfonts/${font}.woff2`),
  ),
  fontAwesomeFour('css/font-awesome.min.css'),
  ...['eot', 'svg', 'ttf', 'woff', 'woff2'].map(
    (format: string): VendoredFile => fontAwesomeFour(`fonts/fontawesome-webfont.${format}`),
  ),
]

/** Where the vendor directory serves Asciidoctor's default stylesheet. */
export const ASCIIDOCTOR_STYLESHEET: string = 'asciidoctor/asciidoctor-default.css'

/** Where the vendor directory serves the font faces, beside the font files they name. */
export const FONT_STYLESHEET: string = 'fonts/fonts.css'

const FONT_DIRECTORY: string = path.dirname(FONT_STYLESHEET)

/**
 * A Fontsource stylesheet of the faces the documents set, and the family and weights to declare its faces as. A
 * variable font is declared once for each weight the theme sets, so that a weight the theme does not name is
 * matched, and an emphasis it does not provide is synthesised, as with the static faces it replaces.
 */
interface FontSource {
  readonly stylesheet: string
  readonly family?: string
  readonly weights?: readonly number[]
}

const SOURCE_SERIF: string = 'Source Serif 4'

const REGULAR: number = 400

const SEMIBOLD: number = 600

const BOLD: number = 700

// The faces the theme sets, the same families, weights and styles the documents loaded before.
const FONTS: readonly FontSource[] = [
  ...['400', '500', '600', '700', '400-italic', '600-italic'].map(
    (face: string): FontSource => ({ stylesheet: path.join(PLAYFAIR_DISPLAY, `${face}.css`) }),
  ),
  { stylesheet: path.join(SOURCE_SERIF_FOUR, 'opsz.css'), family: SOURCE_SERIF, weights: [REGULAR, SEMIBOLD, BOLD] },
  { stylesheet: path.join(SOURCE_SERIF_FOUR, 'opsz-italic.css'), family: SOURCE_SERIF, weights: [REGULAR] },
  ...['400', '600'].map((face: string): FontSource => ({ stylesheet: path.join(SOURCE_CODE_PRO, `${face}.css`) })),
]

const FONT_FACE: RegExp = /@font-face\s*\{[^}]*\}/gu

const FONT_FILE: RegExp = /url\(\.\/files\/(?<file>[^)]+)\)/gu

const FAMILY: RegExp = /font-family:\s*'[^']*'/u

const WEIGHT: RegExp = /font-weight:[^;]+;/u

const asciidoctorStylesheet = (): string => {
  const root: string = path.join('node_modules', ASCIIDOCTOR_PACKAGE)
  return path.join(
    ASCIIDOCTOR_MODULE.slice(0, ASCIIDOCTOR_MODULE.lastIndexOf(root) + root.length),
    'data',
    'asciidoctor-default.css',
  )
}

const facesOf = (source: FontSource, css: string): readonly string[] =>
  Array.from(css.matchAll(FONT_FACE), (match: RegExpExecArray): string => {
    const face: string = match[0].replaceAll(FONT_FILE, 'url($<file>)')
    const family: string | undefined = source.family
    return family === undefined ? face : face.replace(FAMILY, (): string => `font-family: '${family}'`)
  }).flatMap((face: string): readonly string[] =>
    source.weights === undefined
      ? [face]
      : source.weights.map((weight: number): string =>
          face.replace(WEIGHT, (): string => `font-weight: ${String(weight)};`),
        ),
  )

// The directory a Fontsource stylesheet names its font files in, relative to itself.
const fontFilesOf = (source: FontSource): string => path.join(path.dirname(source.stylesheet), 'files')

const filesOf = (css: string): readonly string[] =>
  Array.from(css.matchAll(FONT_FILE), (match: RegExpExecArray): string => match.groups?.['file'] ?? '')

// Every face of every font source in one stylesheet, with the font files it names copied beside it.
const writeFonts = async (directory: string): Promise<void> => {
  await mkdir(directory, { recursive: true })
  const sheets: readonly (readonly [FontSource, string])[] = await Promise.all(
    FONTS.map(
      async (source: FontSource): Promise<readonly [FontSource, string]> => [
        source,
        await readFile(source.stylesheet, 'utf8'),
      ],
    ),
  )
  await Promise.all(
    sheets.flatMap(([source, css]: readonly [FontSource, string]): readonly Promise<void>[] =>
      filesOf(css).map(
        async (file: string): Promise<void> =>
          copyFile(path.join(fontFilesOf(source), file), path.join(directory, file)),
      ),
    ),
  )
  const faces: readonly string[] = sheets.flatMap(([source, css]: readonly [FontSource, string]): readonly string[] =>
    facesOf(source, css),
  )
  await writeFile(path.join(directory, path.basename(FONT_STYLESHEET)), `${faces.join('\n\n')}\n`)
}

const copyInto = async (source: string, destination: string): Promise<void> => {
  await mkdir(path.dirname(destination), { recursive: true })
  await copyFile(source, destination)
}

// The third-party files the stylesheets import, served from the site itself, so a published document asks no
// other origin for a style, a font or an icon.
const writeVendored = async (destination: string): Promise<void> => {
  const vendor: string = path.join(destination, VENDOR)
  await Promise.all([
    ...VENDORED_FILES.map(
      async (file: VendoredFile): Promise<void> => copyInto(file.source, path.join(vendor, file.target)),
    ),
    copyInto(asciidoctorStylesheet(), path.join(vendor, ASCIIDOCTOR_STYLESHEET)),
    writeFonts(path.join(vendor, FONT_DIRECTORY)),
  ])
}

// The documents load the footer script with a plain script element, so the bundle is a classic script: one
// function expression that runs at once, with nothing at its top level a module would need.
const BANNER: string =
  '/* Built from the TypeScript sources under docs/src of https://github.com/ciechanowiec/linux_mantra. */'

/**
 * Builds the GitHub Pages site: the footer script bundled into a classic script, beside the stylesheets and the
 * third-party files they import. The footer script and the stylesheets land at the top of the destination, so the
 * site serves each at the URL the documents name.
 * @param destination the directory to replace with the site, which is never a tracked one
 */
export const buildSite = async (destination: string): Promise<void> => {
  await rm(destination, { recursive: true, force: true })
  await mkdir(destination, { recursive: true })
  await build({
    absWorkingDir: PROJECT,
    entryPoints: ['src/main.ts'],
    outfile: path.join(destination, FOOTER_SCRIPT),
    bundle: true,
    format: 'iife',
    platform: 'browser',
    target: 'es2020',
    banner: { js: BANNER },
    legalComments: 'none',
    logLevel: 'warning',
  })
  await Promise.all([
    ...STYLESHEETS.map(
      async (name: string): Promise<void> =>
        copyFile(path.join(PROJECT, 'src', 'styles', name), path.join(destination, name)),
    ),
    writeVendored(destination),
  ])
}
