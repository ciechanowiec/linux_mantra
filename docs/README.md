# GitHub Pages Site

This node project builds the files that AsciiDoc documents across the author's repositories load from `https://www.ciechanowiec.eu/linux_mantra/`: the stylesheets `adoc-css-style.css` and `adoc-docinfo.css`, the icon stylesheet `font-awesome.css`, and the footer script `adoc-docinfo-footer.js`, which the documents load with a plain `<script src>` element. The site serves everything these files import itself, so a document asks no other origin for a style, a font, an icon or a script.

## Layout

- `src/styles/` holds the three stylesheets, published as they are. Asciidoctor links `font-awesome.css` from the styles directory of a document whose header turns `iconfont-remote` off.
- `src/` holds the TypeScript sources of the footer script, one module per behaviour, with `src/main.ts` starting them in their original order. The footer script bundles tocbot.
- `scripts/build.ts` bundles `src/main.ts` into a classic script, copies the stylesheets into `target/site`, and writes `target/site/vendor`: the fonts, Asciidoctor's default stylesheet and Font Awesome, each taken from the npm package that publishes it.
- `tests/` holds the Vitest specs, which run the behaviours against a rendered Asciidoctor document and check that no stylesheet the site serves names another origin.

## Building and Publishing

`mvn verify` at the repository root runs the build through the `pages-site` execution of the root `pom.xml` and checks the project. The workflow `.github/workflows/pages.yml` builds the same way on every push to `master` and deploys `target/site` as the site root, so every file keeps its URL.
