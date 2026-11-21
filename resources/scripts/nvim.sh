#!/bin/bash

# Ensure brew-installed nvim is on PATH when invoked from non-interactive
# contexts (e.g. GNOME custom keybindings), which skip ~/.bashrc's body.
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    brewShellenv=$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
    eval "${brewShellenv}"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    brewShellenv=$(/opt/homebrew/bin/brew shellenv)
    eval "${brewShellenv}"
fi

resetCursor() {
  case "$(uname)" in
    # For Linux-based systems
    Linux)
      printf '\e[0 q'
      ;;

    # For macOS
    Darwin)
      # Check for iTerm2
      if [[ ${TERM_PROGRAM} == "iTerm.app" ]]; then
        printf '\e[6 q'
      else
        :
      fi
      ;;

    # Default case
    *)
      :
      ;;
  esac
}

if [[ "$#" -eq 0 ]]; then
    nvim -c ":e ${HOME}/Desktop/text-note-${RANDOM}.txt" -c "startinsert"; resetCursor
else
    nvim -c "startinsert" "$@"; resetCursor
fi
