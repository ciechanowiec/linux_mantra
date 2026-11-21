import { copyFile, mkdir, rm } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const PROJECT: string = fileURLToPath(new URL('../', import.meta.url))

/** The name the published documents load the footer script by. */
export const FOOTER_SCRIPT: string = 'adoc-docinfo-footer.js'

/** The stylesheets the published documents load, served under the names they have in `src/styles`. */
export const STYLESHEETS: readonly string[] = ['adoc-css-style.css', 'adoc-docinfo.css']

// The documents load the footer script with a plain script element, so the bundle is a classic script: one
// function expression that runs at once, with nothing at its top level a module would need.
const BANNER: string =
  '/* Built from the TypeScript sources under docs/src of https://github.com/ciechanowiec/linux_mantra. */'

/**
 * Builds the GitHub Pages site: the footer script bundled into a classic script, beside the stylesheets. Every file
 * lands at the top of the destination, so the site serves it at the URL the documents name.
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
  await Promise.all(
    STYLESHEETS.map(
      async (name: string): Promise<void> =>
        copyFile(path.join(PROJECT, 'src', 'styles', name), path.join(destination, name)),
    ),
  )
}
