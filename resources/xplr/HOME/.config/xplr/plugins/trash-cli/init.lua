-- This plugin is a modification of this plugin:
-- https://github.com/sayanarijit/trash-cli.xplr

local function setup(args)

  local xplr = xplr

  if args == nil then
    args = {}
  end

  if args.trash_mode == nil then
    args.trash_mode = "delete"
  end

  if args.trash_key == nil then
    args.trash_key = "d"
  end

  if args.restore_mode == nil then
    args.restore_mode = "delete"
  end

  if args.restore_key == nil then
    args.restore_key = "r"
  end

  -- Trash: delete
  xplr.config.modes.builtin[args.trash_mode].key_bindings.on_key[args.trash_key] = {
    help = "trash",
    messages = {
        {
          BashExecSilently = [===[
          while IFS= read -r line; do
            if trash-put "${line:?}"; then
              echo LogSuccess: "Trashed $line" >> "${XPLR_PIPE_MSG_IN:?}"
            else
              echo LogError: "Failed to trash $line" >> "${XPLR_PIPE_MSG_IN:?}"
            fi
          done < "${XPLR_PIPE_RESULT_OUT:?}"

          echo ExplorePwdAsync >> "${XPLR_PIPE_MSG_IN:?}"
          ]===]
        },
        "PopMode",
    },
  }

  -- Trash: restore
  xplr.config.modes.builtin[args.restore_mode].key_bindings.on_key[args.restore_key] = {
    help = "restore",
    messages = {
      {
        BashExec = [===[
	pathToRestore=$(trash-list | fzf -m | cut -d ' ' -f3-)
	if ([ -n "$pathToRestore" ]) 
	  then
	    echo "Path " $pathToRestore " exists"
	    yes 0 | trash-restore $pathToRestore > /dev/null
	    exitCode=$?
	    if [ $exitCode -eq 0 ] 
	      then
		echo FocusPath: "$pathToRestore" >> "${XPLR_PIPE_MSG_IN:?}"
		echo LogSuccess: "Restored $pathToRestore" >> "${XPLR_PIPE_MSG_IN:?}"
	      else
	 	echo LogError: "Failed to restore $pathToRestore" >> "${XPLR_PIPE_MSG_IN:?}"
	      fi
	  else
	    echo LogError: "Searched file doesn't exist" >> "${XPLR_PIPE_MSG_IN:?}"
	fi
	echo ExplorePwdAsync >> "${XPLR_PIPE_MSG_IN:?}"
        ]===]
      },
      "PopMode",
    },
  }
end

return { setup = setup }
