#!/bin/bash

osType="$1"

# The Cursor installer and every configuration file below are identical on Linux
# and macOS, so $osType is only validated here - it is accepted to keep the call
# signature uniform with the sibling configure_codex.sh / configure_copilot.sh.
if [ "$osType" != "linux" ] && [ "$osType" != "mac" ]; then
    echo "Usage: configure_cursor.sh <linux|mac>"
    exit 1
fi

# Deep-merges a jq filter into a JSON file, creating it when absent. A file that
# is not valid JSON is preserved as a .bak sidecar rather than silently
# discarded, and the managed defaults are re-applied on a clean object.
merge_json_file() {
    targetFile="$1"
    jqFilter="$2"

    mkdir -p "$(dirname "$targetFile")"
    if [ ! -s "$targetFile" ]; then
        echo '{}' > "$targetFile"
    fi
    if ! jq -e . "$targetFile" > /dev/null 2>&1; then
        echo "   $targetFile is not valid JSON. Backing it up to $targetFile.bak and starting fresh."
        mv "$targetFile" "$targetFile.bak"
        echo '{}' > "$targetFile"
    fi
    jq "$jqFilter" "$targetFile" > "$targetFile.tmp" \
        && mv "$targetFile.tmp" "$targetFile"
}

echo "Installing Cursor CLI (Cursor's terminal-based AI coding agent)..."
# Installation docs: https://cursor.com/docs/cli/installation
# NOTES:
#   The official installer is the only supported route (no apt/brew/npm
#   package). It unpacks into $HOME/.local/share/cursor-agent/versions/<version>
#   and symlinks $HOME/.local/bin/agent (primary) plus $HOME/.local/bin/
#   cursor-agent (legacy name). The download is atomic and the symlinks are
#   recreated on every run, so re-running the installer doubles as an upgrade -
#   which is why this is not guarded behind a `command -v` check, unlike Codex.
#   Persisting $HOME/.local/bin on PATH is the mantra's job (it knows whether the
#   shell file is .bashrc or .zshrc and appends it grep-guarded in the Claude
#   Code step of the same procedure); exporting it here only makes `agent`
#   reachable for the rest of this script.
export PATH="$HOME/.local/bin:$PATH"
curl https://cursor.com/install -fsS | bash

cursorHome="$HOME/.cursor"
mkdir -p "$cursorHome"

echo "Configuring Cursor CLI defaults..."
# Docs:
#   https://cursor.com/docs/cli/reference/configuration
#   https://cursor.com/docs/cli/reference/permissions
# NOTES:
#   Only keys whose JSON shape is documented with a concrete example or an
#   explicit type are written here. `model`, `channel`, `maxMode`, `sandbox` and
#   `rewind` exist in the schema table but are documented without an example, so
#   they are deliberately left out - an invalid value would make the whole file
#   unparseable. Pick a model in-session with `/model`; Cursor persists it.
#   `approvalMode` is Cursor's closest analogue to Claude Code's permission
#   modes: "allowlist" honours the allow/deny lists below and prompts for
#   everything else, "auto-review" and "unrestricted" loosen that progressively.
#   Set editor.vimMode to true if the Neovim keymap is wanted here too.
#   The display block keeps the minimal/zen chrome preferred on this
#   workstation; flip the flags if a chattier transcript is wanted.
merge_json_file "$cursorHome/cli-config.json" '. * {
  "version": 1,
  "editor": {
    "vimMode": false
  },
  "approvalMode": "allowlist",
  "attribution": {
    "attributeCommitsToAgent": false,
    "attributePRsToAgent": false
  },
  "display": {
    "showLineNumbers": false,
    "showThinkingBlocks": false,
    "showStatusIndicators": false,
    "showStatusLineRunningTime": false,
    "zenMode": true
  }
}
| .permissions.allow = (((.permissions.allow // []) + [
    "Read(**)",
    "Shell(asciidoctor)",
    "Shell(asciidoctor-pdf)",
    "Shell(cat)",
    "Shell(cut)",
    "Shell(df)",
    "Shell(diff)",
    "Shell(du)",
    "Shell(echo)",
    "Shell(file)",
    "Shell(git)",
    "Shell(grep)",
    "Shell(head)",
    "Shell(jq)",
    "Shell(kramdoc)",
    "Shell(ls)",
    "Shell(pandoc)",
    "Shell(pdfinfo)",
    "Shell(pdftotext)",
    "Shell(realpath)",
    "Shell(rg)",
    "Shell(sort)",
    "Shell(stat)",
    "Shell(tail)",
    "Shell(tr)",
    "Shell(tree)",
    "Shell(uniq)",
    "Shell(vale)",
    "Shell(wc)",
    "Shell(which)",
    "Mcp(context7:*)",
    "Mcp(drawio:*)",
    "WebFetch(*.github.com)",
    "WebFetch(*.adobe.com)",
    "WebFetch(*.apache.org)",
    "WebFetch(*.mozilla.org)",
    "WebFetch(nextjs.org)",
    "WebFetch(payloadcms.com)",
    "WebFetch(www.typescriptlang.org)"
  ]) | unique)
| .permissions.deny = (((.permissions.deny // []) + [
    "Read(**/.env)",
    "Read(**/.env.*)",
    "Read(**/*.pem)",
    "Read(**/id_rsa*)",
    "Write(**/.env)",
    "Write(**/.env.*)",
    "Shell(dd)",
    "Shell(git:clean)",
    "Shell(git:push)",
    "Shell(git:reset)",
    "Shell(halt)",
    "Shell(killall)",
    "Shell(launchctl)",
    "Shell(mkfs)",
    "Shell(npm:publish)",
    "Shell(pkill)",
    "Shell(pnpm:publish)",
    "Shell(reboot)",
    "Shell(rm)",
    "Shell(shutdown)",
    "Shell(sudo)",
    "Shell(systemctl)",
    "Shell(yarn:publish)"
  ]) | unique)'

echo "Registering MCP servers for Cursor CLI..."
# Docs: https://cursor.com/docs/context/mcp
# NOTES:
#   ~/.cursor/mcp.json is shared with the Cursor GUI editor - the CLI simply
#   picks it up - so these servers become available in both. The list mirrors
#   the servers wired into Claude Code and Codex. Project-level .cursor/mcp.json
#   files still take precedence.
merge_json_file "$cursorHome/mcp.json" '.mcpServers = ((.mcpServers // {}) * {
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  },
  "drawio": {
    "command": "npx",
    "args": ["-y", "@drawio/mcp"]
  },
  "playwright": {
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest"]
  },
  "chrome-devtools": {
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp"]
  }
})'

echo "Cloning the official Cursor plugin marketplace..."
# Catalogue: https://github.com/cursor/plugins
# NOTES:
#   The Cursor CLI cannot install plugins: `agent plugin` offers only
#   `marketplace add|list|remove|update`, and installing is an account-scoped
#   action done in the Cursor GUI (Customize -> Install). The official
#   marketplace is moreover already registered out of the box - `agent plugin
#   marketplace list --format json` reports "cursor-public" with an empty gitUrl
#   and global scope - so there is nothing to `marketplace add` either.
#   What the CLI does support is `--plugin-dir`, which loads a plugin directory
#   from disk. So the catalogue is cloned here and ~/scripts/cursor.sh passes the
#   wanted plugins in - launch the agent through that wrapper instead of bare
#   `agent` to get them. Edit the list in that script to change the selection;
#   the clone holds all of them.
#   The clone is shallow; `git pull --ff-only` on a shallow clone just fetches
#   the new tip, so re-runs of the mantra refresh the catalogue cheaply.
cursorPluginsRepo="$cursorHome/marketplaces/cursor-plugins"
if [ -d "$cursorPluginsRepo/.git" ]; then
    git -C "$cursorPluginsRepo" pull --quiet --ff-only
else
    mkdir -p "$(dirname "$cursorPluginsRepo")"
    git clone --depth 1 --quiet https://github.com/cursor/plugins.git "$cursorPluginsRepo"
fi

for cursorPlugin in thermos pr-review-canvas docs-canvas continual-learning cursor-team-kit; do
    if [ -f "$cursorPluginsRepo/$cursorPlugin/.cursor-plugin/plugin.json" ]; then
        echo "   Cursor plugin available: $cursorPlugin"
    else
        echo "   Cursor plugin MISSING from the catalogue (renamed upstream?): $cursorPlugin"
    fi
done

# NOTE ON GLOBAL INSTRUCTIONS:
#   Unlike Codex (~/.codex/AGENTS.md) and Copilot (~/.copilot/
#   copilot-instructions.md), Cursor has no documented home-directory
#   instructions file - `~/.cursor/rules` is still an open feature request, and
#   User Rules live in the Cursor GUI (Settings -> Rules), which the CLI shares.
#   Per-repository guidance is picked up from AGENTS.md, CLAUDE.md and
#   .cursor/rules/*.mdc at the project root, so no global file is written here.

echo "Cursor CLI setup complete. Run 'agent login' later to authenticate on this machine ('agent status' verifies it)."
