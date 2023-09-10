#!/bin/bash

reset_cursor() {
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
    nvim -c 'startinsert'; reset_cursor
else
    nvim "$@"; reset_cursor
fi
