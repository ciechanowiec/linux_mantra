# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Not an application — a personalized, interactive setup script for the author's Linux/Java/AEM (and parallel macOS) workstation. The deliverables are two long, top-level Bash scripts that drive every step of provisioning a freshly installed OS:

- `linux_mantra.sh` (~2.9k lines) — Ubuntu 22.x (`jammy`)
- `mac_mantra.sh` (~2.3k lines) — macOS 26

Each script is the entry point for its platform. Together with the sibling `resources/` directory, they form a self-contained tool: the scripts hardcode paths into `resources/` and copy/source/trigger files from there.

## Running and sanity-checking

- The scripts are run by the user on a fresh OS install, **as a normal user without `sudo`** (the script invokes `sudo` itself where needed; running the whole script under `sudo` corrupts `$HOME`).
- The script creates and chdirs into `$HOME/TEMP` as its working directory and `trash-put`s it at the end. Therefore it must not be launched from inside `$HOME/TEMP`. Final cleanup uses `trash-put`, not `rm`.
- Execution is **interactive by design**: each procedure ends with `promptOnContinuation` (`Proceed? [Y/n]`). Do not refactor toward "fully automatic" — the author has explicitly chosen this for security and editability (see README.adoc §How to Run).
- Do not actually execute the mantra scripts from Claude Code. They make destructive, machine-wide changes (`apt`, `dconf`, `defaults write`, file moves into `$HOME`, etc.) and assume a clean Ubuntu/macOS install.
- For local validation of edits, syntax-check only: `bash -n linux_mantra.sh` and `bash -n mac_mantra.sh`. There is no test suite, linter config, or CI.

## Script structure (load-bearing conventions)

Both top-level scripts follow the same skeleton; understand it before editing:

1. **Header block "COMMON FUNCTIONS AND VARIABLES"** defines the helpers used throughout: `procedureId`, `informAboutProcedureStart`, `informAboutProcedureEnd`, `promptOnContinuation`.
2. **"1. ENVIRONMENT PREPARATION"** sets `initialWorkingDirectory`, `originalScriptDir`, `resourcesDir="$originalScriptDir/resources"`, `tempDir="$HOME/TEMP"`, detects the OS, and `cd`s into `$tempDir`. All subsequent procedures assume these variables exist.
3. **Procedural blocks** follow, each visually framed by a `#####…#####` banner with a numbered title (`1.`, `2.`, …`20. CLEANUP`). Every block:
   - sets `procedureId="…"`,
   - prints `# DOCUMENTATION:` notes,
   - calls `informAboutProcedureStart`,
   - does its work with echoed step numbers (`echo "1. …"`),
   - calls `informAboutProcedureEnd` and `promptOnContinuation`.
4. **Heading numbers encode priority, not identity.** Lower numbers must run before higher numbers; duplicates (e.g. several blocks numbered `12.`) signal "same priority, arbitrary order among themselves." When inserting a new block, pick a number reflecting its dependency relationship with neighbors — don't renumber the whole file to make them unique.

Other conventions:

- `linux_mantra.sh` carries some macOS-shaped code (and `mac_mantra.sh` some Linux-shaped code) as scaffolding for a future cross-platform consolidation. On the wrong OS it's guarded out and dormant; keep both branches consistent when editing shared logic.
- Resource paths are written out explicitly as `$resourcesDir/<subdir>/<file>` rather than computed. If you move a file under `resources/`, grep both top-level scripts for the old path and update every reference.
- The scripts deliberately do not use `set -euo pipefail`. Failure handling is explicit per command (`|| exit 1`, `if [ ! -d … ]; then … exit 1; fi`). Match that style instead of adding global strict-mode flags.
- New helper scripts that the mantra triggers belong under `resources/scripts/` and should be `chmod +x` before commit.

## Resources layout (what each subtree is for)

- `resources/linux/`, `resources/mac/` — OS-specific config payloads dropped onto the target system.
- `resources/scripts/` — standalone helper scripts the mantra installs into the user's PATH (e.g. `mantra_java.sh`, `mantra_ts.sh`, `idea.sh`, `xplr.sh`, the `colima_*` and `docker_clean*` family).
- `resources/adoc_template/`, `resources/typescript_template/`, `resources/demoproject/`, `resources/payload/` — project skeletons used by the `mantra_*` generator scripts.
- `resources/fernflower/` — bundled `fernflower.jar` (the script mounts it instead of installing a separate decompiler; CFR was tried and rejected — see comments in the FERNFLOWER block).
- `resources/font/`, `resources/xplr/`, `resources/static_code_analysis/`, `resources/intellij-idea-*-settings-export.zip` — assets the script copies into place.

## Documentation files

- `README.adoc` — user-facing description and run instructions.
- `resources/adoc_template/README-guideline.adoc` — an AsciiDoc style/structure guideline. Per the user's memory, this document is fed almost exclusively to AI as style instructions, so when editing it, optimize for clarity-to-an-LLM rather than human prose polish.
- `docs/` and the root `docinfo*.html` files are AsciiDoc styling assets, not project documentation.
