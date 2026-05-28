# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Not an application — a personalized, interactive setup script for the author's Linux/Java/AEM (and parallel macOS) workstation. The deliverables are two long, top-level Bash scripts that drive every step of provisioning a freshly installed OS:

- `linux_mantra.sh` (~2.9k lines) — Ubuntu 26.x (`resolute`)
- `mac_mantra.sh` (~2.3k lines) — macOS 26

Each script is the entry point for its platform. Together with the sibling `resources/` directory, they form a self-contained tool: the scripts hardcode paths into `resources/` and copy/source/trigger files from there.

## Running and sanity-checking

- The scripts are run by the user on a fresh OS install, **as a normal user without `sudo`** (the script invokes `sudo` itself where needed; running the whole script under `sudo` corrupts `$HOME`).
- The script creates and chdirs into `$HOME/TEMP` as its working directory and `trash-put`s it at the end. Therefore it must not be launched from inside `$HOME/TEMP`. Final cleanup uses `trash-put`, not `rm`.
- Execution is **interactive by design**: each procedure ends with `promptOnContinuation` (`Proceed? [Y/n]`). Do not refactor toward "fully automatic" — the author has explicitly chosen this for security and editability (see README.adoc §How to Run).
- Do not actually execute the mantra scripts from Claude Code. They make destructive, machine-wide changes (`apt`, `dconf`, `defaults write`, file moves into `$HOME`, etc.) and assume a clean Ubuntu/macOS install.
- For local validation of edits, syntax-check only: `bash -n linux_mantra.sh` and `bash -n mac_mantra.sh`. There is no test suite, linter config, or CI.

## Approaching changes: look past the literal request

This repo provisions one specific, *moving* target (currently Ubuntu 26 "resolute" / macOS 26). A request phrased as a narrow edit usually has second-order consequences that aren't visible at the edit site. Before calling a change done, check three things:

1. **Is it coupled to the OS / desktop-environment release?** OS-shipped defaults change between releases and usually aren't a version string you can grep. When a change touches package names, default apps, OS-shipped tools, GNOME/`dconf`/`gsettings` schema paths or app IDs, GNOME-Shell extensions, or download URLs, treat the target release as a dependency that may have moved — verify the name/path/URL still exists and is still the default on the *current* target instead of assuming continuity from an older release. (Trap to remember: the default GUI terminal is release-coupled — older Ubuntu shipped `gnome-terminal`, current ships `ptyxis`; a "bump the OS" that only edits version strings silently leaves terminal launches, `dconf` keybindings, app IDs, and the profile block pointing at a program that no longer exists.)
2. **Where else does this fact live?** Identifiers and settings are duplicated across the tree, not centralized — the same value can appear in both top-level scripts, `resources/scripts/*.sh`, `resources/**/*.lua`, and `dconf` dumps like `resources/linux/desktopSettingsFile.txt`, sometimes in different forms. The pinned-version rule below is one case of a general habit: after changing a value in one file, `grep -rn` the whole repo (including `resources/`) for siblings and fix them in the same pass. Other duplicated facts: the release-name guard `expectedLinuxReleaseName="resolute"` (top-level scripts + ~6 helper scripts under `resources/scripts/`), the JetBrains Mono Nerd Font (download URLs/filenames in the top-level script vs. the `font-name` setting `JetBrainsMonoNL Nerd Font Mono` in config payloads), and terminal app IDs (launches + keybindings + notification settings).
3. **Does the surrounding code imply more work?** Don't stop at the matching line — read the whole procedural block, both mirrored OS branches, and the resource files that block copies/sources/triggers. Prefer verifying against reality (does the package exist on the target? does the URL resolve? does the schema path still exist?) over carrying an assumption forward from a previous release.

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
- **Software versions are pinned in multiple files, not just the top-level mantra scripts.** Helper scripts under `resources/scripts/` (e.g. `aem_init_archetype.sh` pins both a Java 8 and a Java 11 SDKMAN identifier) and config payloads under `resources/` (e.g. `resources/xplr/HOME/.config/xplr/3_custom_commands-*.lua` pin a Java 21 SDKMAN identifier) reuse the same pins as `linux_mantra.sh` / `mac_mantra.sh`. When bumping any pinned version (Java/Maven via SDKMAN, Insync `.deb`, iTerm2 `.zip`, NVIDIA driver branch, GNOME extension `.zip` URL, xplr release tag, etc.), **before editing, grep the entire repo for every occurrence of the old version string** (e.g. `grep -rEn '8\.0\.492-zulu|11\.0\.31-tem|…' .`) and update them all in one pass. Updating only the top-level scripts will leave drifted references in `resources/`.

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
