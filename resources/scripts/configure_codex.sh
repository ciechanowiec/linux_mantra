#!/bin/bash

osType="$1"

if [ -z "$osType" ]; then
    echo "Usage: configure_codex.sh <linux|mac>"
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

set_root_toml_value() {
    targetFile="$1"
    settingName="$2"
    settingValue="$3"
    tmpFile="$targetFile.tmp"

    mkdir -p "$(dirname "$targetFile")"
    touch "$targetFile"
    awk -v name="$settingName" -v value="$settingValue" '
        BEGIN {
            print name " = " value
            inRoot = 1
        }
        inRoot && /^[[:space:]]*\[/ { inRoot = 0 }
        inRoot {
            candidate = $0
            sub(/=.*/, "", candidate)
            gsub(/[[:space:]]/, "", candidate)
            if (candidate == name) {
                next
            }
        }
        { print }
    ' "$targetFile" > "$tmpFile" && mv "$tmpFile" "$targetFile"
}

set_toml_table_value() {
    targetFile="$1"
    tableName="$2"
    settingName="$3"
    settingValue="$4"
    tmpFile="$targetFile.tmp"

    mkdir -p "$(dirname "$targetFile")"
    touch "$targetFile"
    awk -v table="$tableName" -v name="$settingName" -v value="$settingValue" '
        function printSetting() {
            print name " = " value
        }
        function flushPendingBlankLines() {
            while (pendingBlankLines > 0) {
                print ""
                pendingBlankLines--
            }
        }
        $0 == "[" table "]" {
            foundTable = 1
            inTargetTable = 1
            pendingBlankLines = 0
            print
            next
        }
        inTargetTable && skippingArray {
            if ($0 ~ /^[[:space:]]*\]/) {
                skippingArray = 0
            }
            next
        }
        inTargetTable && /^[[:space:]]*$/ {
            pendingBlankLines++
            next
        }
        inTargetTable && /^[[:space:]]*\[/ {
            printSetting()
            print ""
            pendingBlankLines = 0
            inTargetTable = 0
        }
        inTargetTable {
            candidate = $0
            sub(/=.*/, "", candidate)
            gsub(/[[:space:]]/, "", candidate)
            if (candidate == name) {
                if ($0 ~ /=[[:space:]]*\[/ && $0 !~ /\][[:space:]]*$/) {
                    skippingArray = 1
                }
                pendingBlankLines = 0
                next
            }
            flushPendingBlankLines()
            print
            next
        }
        { print }
        END {
            if (inTargetTable) {
                printSetting()
            } else if (!foundTable) {
                print ""
                print "[" table "]"
                printSetting()
            }
        }
    ' "$targetFile" > "$tmpFile" && mv "$tmpFile" "$targetFile"
}

install_codex_plugin() {
    pluginSelector="$1"

    if codex plugin list --json 2>/dev/null \
        | jq -e --arg pluginId "$pluginSelector" \
            'any(.installed[]; .pluginId == $pluginId)' >/dev/null; then
        echo "Codex plugin already installed: $pluginSelector"
        return
    fi

    echo "Installing Codex plugin: $pluginSelector"
    if ! codex plugin add "$pluginSelector" --json >/dev/null 2>&1; then
        echo "Could not install $pluginSelector automatically. Install it later from Codex with /plugins."
    fi
}

remove_codex_plugin() {
    pluginSelector="$1"

    if codex plugin list --json 2>/dev/null \
        | jq -e --arg pluginId "$pluginSelector" \
            'any(.installed[]; .pluginId == $pluginId)' >/dev/null; then
        echo "Removing Codex plugin: $pluginSelector"
        codex plugin remove "$pluginSelector" --json >/dev/null
    fi
}

echo "Installing Codex CLI (OpenAI's terminal-based AI coding agent)..."
if command -v codex >/dev/null 2>&1; then
    echo "Codex CLI already installed:"
    codex --version
elif [ "$osType" = "mac" ]; then
    brew install --cask codex
elif [ "$osType" = "linux" ]; then
    sudo npm install -g @openai/codex
else
    echo "Unsupported OS type for Codex setup: $osType"
    exit 1
fi

echo "Configuring Codex defaults..."
codexHome="$HOME/.codex"
codexConfigFile="$codexHome/config.toml"
mkdir -p "$codexHome/rules"

# Primary model and reasoning defaults. This mirrors the Claude Code "opus"
# preference with Codex's strongest default model.
set_root_toml_value "$codexConfigFile" "model" '"gpt-5.6"'
set_root_toml_value "$codexConfigFile" "review_model" '"gpt-5.6"'
set_root_toml_value "$codexConfigFile" "model_context_window" "1050000"
set_root_toml_value "$codexConfigFile" "model_reasoning_effort" '"xhigh"'
set_root_toml_value "$codexConfigFile" "plan_mode_reasoning_effort" '"xhigh"'
set_root_toml_value "$codexConfigFile" "model_verbosity" '"high"'
set_root_toml_value "$codexConfigFile" "personality" '"pragmatic"'

# Codex does not inherit Claude Code's deny rules, so keep approval prompts and
# workspace isolation instead of mirroring Claude's bypassPermissions mode.
set_root_toml_value "$codexConfigFile" "approval_policy" '"on-request"'
set_root_toml_value "$codexConfigFile" "sandbox_mode" '"workspace-write"'
set_root_toml_value "$codexConfigFile" "web_search" '"live"'

# Let Codex consume existing Claude-oriented repository guidance while repos
# are gradually migrated to AGENTS.md.
set_root_toml_value "$codexConfigFile" "project_doc_fallback_filenames" '["CLAUDE.md"]'
set_root_toml_value "$codexConfigFile" "project_doc_max_bytes" "65536"

# Codex-specific quality-of-life features.
set_toml_table_value "$codexConfigFile" "features" "apps" "true"
set_toml_table_value "$codexConfigFile" "features" "hooks" "true"
set_toml_table_value "$codexConfigFile" "features" "memories" "true"
set_toml_table_value "$codexConfigFile" "features" "multi_agent" "true"
set_toml_table_value "$codexConfigFile" "features" "shell_snapshot" "true"

# Offer both close Claude equivalents and useful Codex-specific capabilities.
set_toml_table_value "$codexConfigFile" "tool_suggest" "discoverables" '[{ type = "plugin", id = "browser@openai-bundled" }, { type = "plugin", id = "chrome@openai-bundled" }, { type = "plugin", id = "computer-use@openai-bundled" }, { type = "plugin", id = "github@openai-curated" }, { type = "plugin", id = "codex-security@openai-curated" }, { type = "plugin", id = "build-web-apps@openai-curated" }, { type = "plugin", id = "openai-developers@openai-curated" }, { type = "plugin", id = "superpowers@openai-curated" }, { type = "plugin", id = "cloudflare@openai-curated" }]'

# Do not suggest Figma even if it is present in a configured marketplace.
set_toml_table_value "$codexConfigFile" "tool_suggest" "disabled_tools" '[{ type = "plugin", id = "figma@openai-curated" }]'

# Update only the owned MCP keys so Codex can retain per-server state such as
# enabled/disabled flags alongside the mantra defaults.
set_toml_table_value "$codexConfigFile" "mcp_servers.context7" "command" '"npx"'
set_toml_table_value "$codexConfigFile" "mcp_servers.context7" "args" '["-y", "@upstash/context7-mcp"]'
set_toml_table_value "$codexConfigFile" "mcp_servers.context7" "startup_timeout_sec" "60"
set_toml_table_value "$codexConfigFile" "mcp_servers.context7" "tool_timeout_sec" "120"
set_toml_table_value "$codexConfigFile" "mcp_servers.context7" "required" "true"

set_toml_table_value "$codexConfigFile" "mcp_servers.openaiDeveloperDocs" "url" '"https://developers.openai.com/mcp"'
set_toml_table_value "$codexConfigFile" "mcp_servers.openaiDeveloperDocs" "startup_timeout_sec" "30"
set_toml_table_value "$codexConfigFile" "mcp_servers.openaiDeveloperDocs" "tool_timeout_sec" "120"
set_toml_table_value "$codexConfigFile" "mcp_servers.openaiDeveloperDocs" "required" "true"

set_toml_table_value "$codexConfigFile" "mcp_servers.drawio" "command" '"npx"'
set_toml_table_value "$codexConfigFile" "mcp_servers.drawio" "args" '["-y", "@drawio/mcp"]'
set_toml_table_value "$codexConfigFile" "mcp_servers.drawio" "startup_timeout_sec" "60"
set_toml_table_value "$codexConfigFile" "mcp_servers.drawio" "tool_timeout_sec" "120"
set_toml_table_value "$codexConfigFile" "mcp_servers.drawio" "required" "true"

set_toml_table_value "$codexConfigFile" "mcp_servers.playwright" "command" '"npx"'
set_toml_table_value "$codexConfigFile" "mcp_servers.playwright" "args" '["-y", "@playwright/mcp@latest"]'
set_toml_table_value "$codexConfigFile" "mcp_servers.playwright" "startup_timeout_sec" "60"
set_toml_table_value "$codexConfigFile" "mcp_servers.playwright" "tool_timeout_sec" "120"
set_toml_table_value "$codexConfigFile" "mcp_servers.playwright" "required" "true"

set_toml_table_value "$codexConfigFile" "mcp_servers.chrome_devtools" "command" '"npx"'
set_toml_table_value "$codexConfigFile" "mcp_servers.chrome_devtools" "args" '["-y", "chrome-devtools-mcp"]'
set_toml_table_value "$codexConfigFile" "mcp_servers.chrome_devtools" "startup_timeout_sec" "60"
set_toml_table_value "$codexConfigFile" "mcp_servers.chrome_devtools" "tool_timeout_sec" "120"
set_toml_table_value "$codexConfigFile" "mcp_servers.chrome_devtools" "required" "true"

echo "Configuring Codex global instructions..."
codexInstructionsFile="$codexHome/AGENTS.md"
replace_managed_block "$codexInstructionsFile" "<!-- BEGIN MANTRA CODEX INSTRUCTIONS -->" "<!-- END MANTRA CODEX INSTRUCTIONS -->" << 'EOF'
When working on software, include brief educational insights about important
implementation choices and codebase patterns, matching Claude Code's
explanatory output style.
EOF

echo "Configuring Codex command approval rules..."
codexRulesFile="$codexHome/rules/default.rules"
replace_managed_block "$codexRulesFile" "# BEGIN MANTRA CODEX RULES" "# END MANTRA CODEX RULES" << 'EOF'
# Prompt-free approvals for common read-only or validation commands that often
# need to run outside the sandbox because they hit the network, package indexes,
# or GitHub. Keep filesystem-wide search commands sandboxed instead of globally
# allowlisting them here.
prefix_rule(pattern=["docker", "compose", "config"], decision="allow")
prefix_rule(pattern=["docker", "compose", "ps"], decision="allow")
prefix_rule(pattern=["docker", "info"], decision="allow")
prefix_rule(pattern=["gh", "pr", "view"], decision="allow")
prefix_rule(pattern=["gh", "run", "list"], decision="allow")
prefix_rule(pattern=["gh", "run", "view"], decision="allow")
prefix_rule(pattern=["npm", "view"], decision="allow")
prefix_rule(pattern=["pnpm", "list"], decision="allow")
prefix_rule(pattern=["pnpm", "outdated"], decision="allow")
prefix_rule(pattern=["pnpm", "why"], decision="allow")
prefix_rule(pattern=["brew", "info"], decision="allow")
prefix_rule(pattern=["brew", "list"], decision="allow")
prefix_rule(pattern=["brew", "outdated"], decision="allow")
prefix_rule(pattern=["brew", "search"], decision="allow")
prefix_rule(pattern=["apt", "list"], decision="allow")
prefix_rule(pattern=["apt", "search"], decision="allow")
prefix_rule(pattern=["apt", "show"], decision="allow")
prefix_rule(pattern=["apt-cache"], decision="allow")
prefix_rule(pattern=["snap", "find"], decision="allow")
prefix_rule(pattern=["snap", "info"], decision="allow")
prefix_rule(pattern=["sdk", "list"], decision="allow")
EOF

if command -v codex >/dev/null 2>&1; then
    remove_codex_plugin "figma@openai-curated"

    echo "Installing Claude-equivalent and Codex-specific plugins..."
    install_codex_plugin "browser@openai-bundled"
    install_codex_plugin "chrome@openai-bundled"
    install_codex_plugin "computer-use@openai-bundled"
    install_codex_plugin "github@openai-curated"
    install_codex_plugin "codex-security@openai-curated"
    install_codex_plugin "build-web-apps@openai-curated"
    install_codex_plugin "openai-developers@openai-curated"
    install_codex_plugin "superpowers@openai-curated"
    install_codex_plugin "cloudflare@openai-curated"
fi

echo "Codex setup complete. Run 'codex login' later to authenticate on this machine."
