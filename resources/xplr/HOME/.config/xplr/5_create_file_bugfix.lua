-- For an unknown reason, on macOS, the default "create file" command defined at
-- https://github.com/sayanarijit/xplr/blob/dev/src/init.lua#L1674 doesn't work
-- correctly. However, simple repetition of that original command in the local
-- init.lua file, which is done below, fixes the problem:
xplr.config.modes.builtin.create_file = {
  name = "create file",
  prompt = "ƒ ❯ ",
  key_bindings = {
    on_key = {
      ["tab"] = {
        help = "try complete",
        messages = {
          { CallLuaSilently = "builtin.try_complete_path" },
        },
      },
      ["enter"] = {
        help = "submit",
        messages = {
          {
            BashExecSilently0 = [===[
              PTH="$XPLR_INPUT_BUFFER"
              PTH_ESC=$(printf %q "$PTH")
              if [ "$PTH" ]; then
                mkdir -p -- "$(dirname $(realpath -m $PTH))"  # This may fail.
                touch -- "$PTH" \
                && "$XPLR" -m 'SetInputBuffer: ""' \
                && "$XPLR" -m 'LogSuccess: %q' "$PTH_ESC created" \
                && "$XPLR" -m 'ExplorePwd' \
                && "$XPLR" -m 'FocusPath: %q' "$PTH"
              else
                "$XPLR" -m PopMode
              fi
            ]===],
          },
        },
      },
    },
    default = {
      messages = {
        "UpdateInputBufferFromKey",
      },
    },
  },
}
