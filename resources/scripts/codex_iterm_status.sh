#!/bin/bash

# Bridges Codex hook events to the iTerm2 tab status indicator.
#
# iTerm2's Claude Code integration installs `cc-status` and symlinks it into
# ~/.config/iterm2. That helper reads a hook payload on stdin, maps its
# `hook_event_name` onto the tab status (working/waiting/idle) and shells out to
# iTerm2's `it2` CLI. Codex emits the same event names as Claude Code, so the
# helper is reused verbatim rather than reimplemented here.
#
# This wrapper exists for one reason: Codex rejects empty output from its Stop,
# SubagentStop and Interrupt hooks ("hook returned invalid stop hook JSON
# output"), while cc-status writes nothing at all. Emitting an empty JSON object
# satisfies the parser for every event - each field of the wire format is
# optional and `continue` defaults to true (see default_continue in
# codex-rs/hooks/src/schema.rs), so `{}` means "success, carry on" rather than
# "halt the turn".
#
# Outside an iTerm2 session cc-status exits without contacting iTerm2, so this
# stays harmless in any other terminal.

ccStatusBinary="$HOME/.config/iterm2/cc-status"

# The payload arrives on stdin and has to be forwarded, not consumed.
hookPayload="$(cat)"

if [ -x "$ccStatusBinary" ]; then
    printf '%s' "$hookPayload" | "$ccStatusBinary" > /dev/null 2>&1
fi

# Always report success: a tab decoration must never fail a Codex turn.
printf '{}\n'
exit 0
