# GitHub Pages Site

This node project builds the files that AsciiDoc documents across the author's repositories load from `https://www.ciechanowiec.eu/linux_mantra/`: the stylesheets `adoc-css-style.css` and `adoc-docinfo.css`, and the footer script `adoc-docinfo-footer.js`, which the documents load with a plain `<script src>` element after tocbot.

## Layout

- `src/styles/` holds the two stylesheets, published as they are.
- `src/` holds the TypeScript sources of the footer script, one module per behaviour, with `src/main.ts` starting them in their original order.
- `scripts/build.ts` bundles `src/main.ts` into a classic script and copies the stylesheets into `target/site`.
- `tests/` holds the Vitest specs, which run the behaviours against a rendered Asciidoctor document.

## Building and Publishing

`mvn verify` at the repository root runs the build through the `pages-site` execution of the root `pom.xml` and checks the project. The workflow `.github/workflows/pages.yml` builds the same way on every push to `master` and deploys `target/site` as the site root, so every file keeps its URL.
