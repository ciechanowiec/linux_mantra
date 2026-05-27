#!/bin/bash

# Ensure brew-installed nvim is on PATH when invoked from non-interactive
# contexts (e.g. GNOME custom keybindings), which skip ~/.bashrc's body.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
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
      if [[ $TERM_PROGRAM == "iTerm.app" ]]; then
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

if [ "$#" -eq 0 ]; then
    nvim -c ":e $HOME/Desktop/text-note-$RANDOM.txt" -c "startinsert"; resetCursor
else
    nvim -c "startinsert" "$@"; resetCursor
fi
