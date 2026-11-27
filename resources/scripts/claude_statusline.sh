#!/bin/bash

# Prints the Claude Code status line: the working directory, with the home
# prefix shortened to ~, followed by a middle dot (U+00B7) and the current Git
# branch, for example `~/0_prog/linux_mantra <dot> master`. The dot is spelled
# as its UTF-8 bytes in an ANSI-C quoted string, which bash 3.2 (the macOS
# /bin/bash) understands, so this file stays plain ASCII.
#
# Claude Code prints the working directory only in its startup banner, which
# scrolls away, and the status line is the one row it keeps on screen. The
# mantra points the `statusLine` setting in ~/.claude/settings.json at this
# script. Claude Code pipes the session as JSON on stdin and shows whatever
# the script prints; see https://code.claude.com/docs/en/statusline.
#
# Claude Code re-runs the script after every change in the session, so it
# reads only HEAD: `git branch --show-current` never touches the index or the
# working tree. A detached HEAD has no branch, so the short commit hash takes
# its place. Outside a repository the branch part is left out.

sessionData="$(cat)"
currentDir="$(jq -r '.workspace.current_dir' <<< "${sessionData}")"

displayDir="${currentDir}"
if [[ "${currentDir}" == "${HOME}" ]] || [[ "${currentDir}" == "${HOME}/"* ]]; then
    displayDir="~${currentDir#"${HOME}"}"
fi

gitRef="$(git -C "${currentDir}" branch --show-current 2> /dev/null)"
if [[ -z "${gitRef}" ]]; then
    gitRef="$(git -C "${currentDir}" rev-parse --short HEAD 2> /dev/null)"
fi

separator=$' \xc2\xb7 '

if [[ -n "${gitRef}" ]]; then
    printf '%s%s%s\n' "${displayDir}" "${separator}" "${gitRef}"
else
    printf '%s\n' "${displayDir}"
fi
