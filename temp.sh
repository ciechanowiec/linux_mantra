#!/bin/bash

osascript -e '
if application "iTerm" is not running then
    tell application "iTerm"
        activate
        delay 1 -- Allow time for iTerm to launch
        create window with default profile
        tell current session of current window
            write text "nvim test.lua"
        end tell
    end tell
else
    tell application "iTerm"
        activate
        if (count of windows) = 0 then
            create window with default profile
        end if
        tell current session of current window
            write text "nvim test.lua"
        end tell
    end tell
end if'
