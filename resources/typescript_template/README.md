# TypeScript Template

This template is a bootstrap for a TypeScript project that runs on Node.js. The repository contains a sample program that prints three lines and the configuration around it: a strict TypeScript compiler setup, Biome for lint and format, Vitest for tests, and a pre-commit hook. The intended workflow is to clone the repository, replace the sample sources under `src/` and `test/`, and keep the surrounding configuration.

This README covers the project layout, the prerequisites, and the available commands.

## Prerequisites

- Node.js 24 or later, declared in `package.json` under `engines`.
- pnpm 11 or later, declared in `package.json` under `packageManager`.

## Project Layout

| Path                         | Purpose                                                                                                                                                                            |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `src/Main.ts`                | Entry point. Constructs a `SamplePrinter` and writes its lines to standard output using a top-level `await`.                                                                       |
| `src/SamplePrinter.ts`       | Class with one `async` method that returns a fixed list of lines. Demonstrates `readonly` fields, constructor parameters, and `Promise` return types.                              |
| `test/SamplePrinter.test.ts` | Vitest test for `SamplePrinter`.                                                                                                                                                   |
| `tsconfig.json`              | Compiler options for the production build. Compiles `src/**/*` to `dist/` with declaration files and source maps. Sets `noEmitOnError: true` so type errors block emit by default. |
| `tsconfig.test.json`         | Extends `tsconfig.json`, adds `test/**/*`, and disables emit. Used for type-checking only.                                                                                         |
| `biome.json`                 | Biome configuration for linting and formatting.                                                                                                                                    |
| `package.json`               | Dependencies, scripts, and the pre-commit hook declaration.                                                                                                                        |
| `pnpm-workspace.yaml`        | Allow-list of build scripts pnpm may run during install. Currently allows only `simple-git-hooks`.                                                                                 |
| `.editorconfig`              | Editor-agnostic indent, line-ending, and trailing-whitespace rules.                                                                                                                |
| `.gitattributes`             | Forces LF line endings in the repository.                                                                                                                                          |
| `.gitignore`                 | Excludes build output, IDE files, and OS metadata from version control.                                                                                                            |

## Install

Install dependencies and register the pre-commit hook:

```bash
pnpm install
```

The `prepare` script in `package.json` runs after install. When the working directory is a git repository, `prepare` registers the hook defined under `simple-git-hooks`. Outside a git repository, `prepare` exits without action so that `pnpm install` still succeeds.

## Build

The template provides two build modes.

The default build, `pnpm run build`, runs the full check suite before emitting JavaScript:

1. `biome check .` reports lint and format problems.
2. `tsc --noEmit -p tsconfig.test.json` type-checks `src/**/*` and `test/**/*` together.
3. `vitest run` runs the test suite once.
4. `tsc` compiles `src/**/*` to `dist/`.

The build stops at the first failing step. The compiler is configured with `noEmitOnError: true`, so even if `tsc` is reached with type errors, no files are written to `dist/`.

The forced build, `pnpm run build:force`, skips the check suite and runs `tsc --noEmitOnError false || true`. Files are written to `dist/` whether or not the source contains type errors, and the script exits with status 0 either way. Use this mode when an intermediate build is needed despite known errors, for example to inspect partial output during refactoring.

## Run the Program

Build, then run the compiled entry point with Node:

```bash
pnpm run build
node dist/Main.js
```

The expected output is:

```
Hello, Universe!
This is the first line from a sample file.
This is the second line from a sample file.
```

## Run the Tests

Run the test suite once and exit:

```bash
pnpm test
```

For watch mode during development:

```bash
pnpm exec vitest
```

## Type-Check

```bash
pnpm run typecheck
```

This runs `tsc --noEmit` against `tsconfig.test.json`, which type-checks both `src/**/*` and `test/**/*` without producing output files.

## Lint and Format

Biome handles both linting and formatting. The configuration in `biome.json` enables strict rules, including no `any`, no `console` (except `error`, `warn`, and `info`), required explicit return types on functions, and a maximum cognitive complexity of 8 per function.

Three scripts are available:

- `pnpm run lint` reports lint problems without modifying files.
- `pnpm run format` rewrites files to match the formatter rules.
- `pnpm run check` runs Biome's combined lint and format check, then the type-check, then the test suite. Run it before committing and in CI.

## Pre-Commit Hook

The hook declared under `simple-git-hooks` in `package.json` runs Biome's check on staged files:

```
pnpm exec biome check --staged --no-errors-on-unmatched
```

The hook is installed by the `prepare` script during `pnpm install`. To re-install it after editing the hook definition in `package.json`, run:

```bash
pnpm exec simple-git-hooks
```

## TypeScript Strictness

The `tsconfig.json` enables every strict-mode flag and several opt-in checks. Four settings have effects worth highlighting:

- `verbatimModuleSyntax` combined with Biome's `useImportExtensions` rule requires imports of local files to use the compiled `.js` extension, even though the source file is `.ts`. Example from `src/Main.ts`: `import { SamplePrinter } from "./SamplePrinter.js"`.
- `noUncheckedIndexedAccess` makes array and record indexing return `T | undefined`. Code that indexes must handle the `undefined` case before using the result.
- `exactOptionalPropertyTypes` distinguishes a property that is missing from one explicitly set to `undefined`.
- `noImplicitOverride` requires the `override` keyword when a subclass method overrides a parent method.

The full meaning of each option is documented in the [TypeScript compiler reference](https://www.typescriptlang.org/tsconfig).
