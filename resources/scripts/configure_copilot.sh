#!/bin/bash

osType="$1"

if [ -z "$osType" ]; then
    echo "Usage: configure_copilot.sh <linux|mac>"
    exit 1
fi

replace_managed_block() {
    targetFile="$1"
    beginMarker="$2"
    endMarker="$3"
    tmpFile="$targetFile.tmp"

    mkdir -p "$(dirname "$targetFile")"
    touch "$targetFile"
    awk -v begin="$beginMarker" -v end="$endMarker" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$targetFile" > "$tmpFile" && mv "$tmpFile" "$targetFile"

    printf "\n%s\n" "$beginMarker" >> "$targetFile"
    cat >> "$targetFile"
    printf "%s\n" "$endMarker" >> "$targetFile"
}

install_copilot_plugin() {
    pluginSelector="$1"

    # `copilot plugin list` prints one "  * <name>@<marketplace> (vX.Y.Z)" line
    # per installed plugin, so a literal grep on the selector is an exact match.
    # `copilot plugin install` is idempotent on its own (a repeat run simply
    # reinstalls); the guard only avoids re-downloading on mantra re-runs.
    if copilot plugin list 2> /dev/null | grep -qF "$pluginSelector"; then
        echo "Copilot plugin already installed: $pluginSelector"
        return
    fi

    echo "Installing Copilot plugin: $pluginSelector"
    if ! copilot plugin install "$pluginSelector" > /dev/null 2>&1; then
        echo "Could not install $pluginSelector automatically. Install it later with 'copilot plugin install $pluginSelector'."
    fi
}

# Deep-merges a jq filter into a JSON file, creating it when absent. Copilot's
# settings.json accepts JSONC (comments), which jq cannot parse; if the file has
# been hand-edited into non-JSON, it is preserved as a .bak sidecar rather than
# silently discarded, and the managed defaults are re-applied on a clean object.
merge_json_file() {
    targetFile="$1"
    jqFilter="$2"

    mkdir -p "$(dirname "$targetFile")"
    if [ ! -s "$targetFile" ]; then
        echo '{}' > "$targetFile"
    fi
    if ! jq -e . "$targetFile" > /dev/null 2>&1; then
        echo "   $targetFile is not plain JSON (comments?). Backing it up to $targetFile.bak and starting fresh."
        mv "$targetFile" "$targetFile.bak"
        echo '{}' > "$targetFile"
    fi
    jq "$jqFilter" "$targetFile" > "$targetFile.tmp" \
        && mv "$targetFile.tmp" "$targetFile"
}

echo "Installing GitHub Copilot CLI (GitHub's terminal-based AI coding agent)..."
# Installation docs: https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli
# NOTES:
#   `copilot` (GitHub Copilot CLI) is a different program from `gh` (GitHub CLI,
#   installed in its own procedure). Both can coexist; only `copilot` is an
#   agentic coding assistant.
#   On macOS the Homebrew cask is the officially recommended route and also
#   installs shell completions. On Linux the npm package is used (it needs the
#   Node.js installed earlier in this procedure - Node 22+ is required).
if command -v copilot > /dev/null 2>&1; then
    echo "GitHub Copilot CLI already installed:"
    copilot --version
elif [ "$osType" = "mac" ]; then
    brew install --cask copilot-cli
elif [ "$osType" = "linux" ]; then
    sudo npm install -g @github/copilot
else
    echo "Unsupported OS type for GitHub Copilot CLI setup: $osType"
    exit 1
fi

copilotHome="$HOME/.copilot"
mkdir -p "$copilotHome"

echo "Configuring GitHub Copilot CLI defaults..."
# Docs: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference
# NOTES:
#   Only settings.json is user-editable. config.json in the same directory holds
#   auto-managed state (credentials, installed plugins) and must not be touched.
#   Copilot has no equivalent of Claude Code's `bypassPermissions`; like the
#   Codex setup, approval prompts are deliberately kept on. Blanket approval is
#   available per-invocation via `copilot --yolo` / the `/yolo` slash command.
#   The model is pinned to Claude Opus 5 with the long-context tier rather than
#   left on "auto", matching the Claude Code preference on this workstation.
merge_json_file "$copilotHome/settings.json" '. * {
  "model": "claude-opus-5",
  "contextTier": "long_context",
  "theme": "github",
  "banner": "never",
  "effortLevel": "high",
  "stream": true,
  "renderMarkdown": true,
  "showTimestamps": true,
  "beep": true,
  "autoUpdate": true,
  "autoUpdatesChannel": "stable",
  "commandHistoryMaxSize": 200,
  "footer": {
    "showModelEffort": true,
    "showDirectory": true,
    "showBranch": true
  },
  "ide": {
    "autoConnect": true,
    "openDiffOnEdit": true
  },
  "sandbox": {
    "enabled": false,
    "allowBypass": true,
    "gitAuth": true,
    "ghAuth": true
  }
}
| .allowedUrls = (((.allowedUrls // []) + [
    "docs.github.com",
    "github.com",
    "raw.githubusercontent.com",
    "developer.adobe.com",
    "experienceleague.adobe.com",
    "sling.apache.org",
    "maven.apache.org",
    "docs.oracle.com",
    "nextjs.org",
    "payloadcms.com",
    "developer.mozilla.org",
    "www.typescriptlang.org"
  ]) | unique)'

echo "Registering user-level MCP servers for GitHub Copilot CLI..."
# Docs: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference
# NOTES:
#   Servers listed here are available in every session regardless of the working
#   directory. GitHub's own MCP server ships built into the CLI, so it is not
#   repeated here; the entries below mirror the servers wired into Claude Code
#   and Codex. Project-level .mcp.json files still win on name conflicts.
#   The top-level key is `mcpServers` and every entry needs `type` and `tools`:
#   the GitHub docs page for this file calls the key `servers` and omits both,
#   but the CLI rejects that shape ("mcpServers: Required"). The schema below is
#   what `copilot mcp add <name> -- <command> <args...>` itself writes.
merge_json_file "$copilotHome/mcp-config.json" '.mcpServers = ((.mcpServers // {}) * {
  "context7": {
    "type": "local",
    "tools": ["*"],
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  },
  "drawio": {
    "type": "local",
    "tools": ["*"],
    "command": "npx",
    "args": ["-y", "@drawio/mcp"]
  },
  "playwright": {
    "type": "local",
    "tools": ["*"],
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest"]
  },
  "chrome-devtools": {
    "type": "local",
    "tools": ["*"],
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp"]
  }
})'

echo "Installing the TypeScript language server (feeds diagnostics to Copilot CLI)..."
# Copilot CLI can consult Language Server Protocol servers for real diagnostics
# and completions instead of guessing types - the counterpart of the
# `typescript-lsp` plugin enabled in Claude Code. On Linux npm's global prefix is
# root-owned, on macOS it is Homebrew-owned, hence the sudo asymmetry (same
# pattern as the other global npm installs in the mantra).
if [ "$osType" = "linux" ]; then
    sudo npm install -g typescript-language-server
else
    npm install -g typescript-language-server
fi

echo "Registering user-level LSP servers for GitHub Copilot CLI..."
# NOTES:
#   Same trap as mcp-config.json above: the GitHub docs page calls the top-level
#   key `servers` and pairs it with a `languages` array, which the CLI ignores.
#   The shape below is the one in the copilot-cli README itself - `lspServers`
#   plus a `fileExtensions` map from extension to language id.
#   Inspect the result with `/lsp show` in an interactive session; `/lsp test
#   typescript` checks that the server actually starts.
merge_json_file "$copilotHome/lsp-config.json" '.lspServers = ((.lspServers // {}) * {
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "fileExtensions": {
      ".ts": "typescript",
      ".tsx": "typescript",
      ".js": "javascript",
      ".jsx": "javascript",
      ".mjs": "javascript",
      ".cjs": "javascript"
    }
  }
})'

echo "Configuring GitHub Copilot CLI global instructions..."
# ~/.copilot/copilot-instructions.md applies to every session, in every repo -
# the counterpart of Codex's ~/.codex/AGENTS.md.
replace_managed_block "$copilotHome/copilot-instructions.md" \
    "<!-- BEGIN MANTRA COPILOT INSTRUCTIONS -->" \
    "<!-- END MANTRA COPILOT INSTRUCTIONS -->" << 'EOF'
When working on software, include brief educational insights about important
implementation choices and codebase patterns, matching Claude Code's
explanatory output style.

Never add yourself as a co-author of commits or pull requests.
EOF

if command -v copilot > /dev/null 2>&1; then
    echo "Installing Copilot plugins matching this workstation's stack..."
    # Docs: https://docs.github.com/copilot/concepts/agents/copilot-cli/about-cli-plugins
    # Catalogs:
    #   https://github.com/github/copilot-plugins  (official, marketplace "copilot-plugins")
    #   https://github.com/github/awesome-copilot  (community, marketplace "awesome-copilot")
    # NOTES:
    #   Both marketplaces ship registered with the CLI, so no
    #   `copilot plugin marketplace add` is needed - which is also why plugins
    #   are driven through the CLI here instead of hand-written into
    #   settings.json (unlike the Claude Code block, whose enabledPlugins shape
    #   is documented).
    #   The official copilot-plugins catalog is almost entirely Microsoft 365 /
    #   Fabric / Power Platform / C++ material, so only its security plugin is
    #   taken; the rest of the picks come from awesome-copilot and mirror the
    #   plugins enabled in Claude Code (security, testing, architecture,
    #   frontend, docs/diagrams) plus this workstation's Java/AEM and
    #   TypeScript/Next.js/Payload work.
    #   Browse the full catalogs with `copilot plugin marketplace browse
    #   awesome-copilot`; drop a plugin later with `copilot plugin uninstall`.
    install_copilot_plugin "advanced-security@copilot-plugins"
    install_copilot_plugin "security-best-practices@awesome-copilot"
    install_copilot_plugin "java-development@awesome-copilot"
    install_copilot_plugin "frontend-web-dev@awesome-copilot"
    install_copilot_plugin "cms-development@awesome-copilot"
    install_copilot_plugin "database-data-management@awesome-copilot"
    install_copilot_plugin "testing-automation@awesome-copilot"
    install_copilot_plugin "software-engineering-team@awesome-copilot"
    install_copilot_plugin "arch@awesome-copilot"
    install_copilot_plugin "project-documenter@awesome-copilot"
fi

echo "GitHub Copilot CLI setup complete. Run 'copilot' and then '/login' later to authenticate on this machine."
