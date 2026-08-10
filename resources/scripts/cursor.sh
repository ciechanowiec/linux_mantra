#!/bin/bash

# Wrapper around the Cursor CLI (`agent`) that loads a curated set of plugins
# from the local clone of the official Cursor plugin marketplace.
#
# WHY THIS WRAPPER EXISTS:
#   Unlike Claude Code (`claude plugin install`) and GitHub Copilot CLI
#   (`copilot plugin install`), the Cursor CLI has no plugin-install command -
#   `agent plugin` exposes only `marketplace add|list|remove|update`, and
#   installing a plugin is an account-scoped action performed in the Cursor GUI
#   (Customize -> Install) or the team dashboard. The one CLI-side mechanism is
#   `--plugin-dir`, which loads a plugin directory straight off disk. The mantra
#   therefore clones github.com/cursor/plugins (see configure_cursor.sh) and this
#   wrapper passes the wanted plugins in on every launch.
#
# Plugins are added/removed by editing the list below; the clone holds the whole
# catalogue, so no re-download is needed. Browse it with:
#   ls ~/.cursor/marketplaces/cursor-plugins

cursorPluginsRepo="$HOME/.cursor/marketplaces/cursor-plugins"

# Curated to this workstation's work, mirroring the plugins enabled in Claude
# Code and GitHub Copilot CLI:
#   thermos            - deep correctness/security branch audits with subagents
#   pr-review-canvas   - PR diffs rendered as a reviewable canvas
#   docs-canvas        - docs/architecture notes as a navigable canvas
#   continual-learning - incremental AGENTS.md memory updates
#   cursor-team-kit    - CI, code review and shipping workflows
cursorPlugins=(
    "thermos"
    "pr-review-canvas"
    "docs-canvas"
    "continual-learning"
    "cursor-team-kit"
)

pluginArgs=()
for cursorPlugin in "${cursorPlugins[@]}"; do
    pluginDir="$cursorPluginsRepo/$cursorPlugin"
    if [ -d "$pluginDir" ]; then
        pluginArgs+=(--plugin-dir "$pluginDir")
    else
        # Missing directory is not fatal: the agent is still perfectly usable
        # without the plugin, so warn and carry on rather than blocking a chat.
        printf 'Cursor plugin directory not found, skipping: %s\n' "$pluginDir" >&2
    fi
done

exec agent "${pluginArgs[@]}" "$@"
