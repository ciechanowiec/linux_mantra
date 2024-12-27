#!/bin/bash

launcherPath="/opt/homebrew/bin/idea"

ps aux | grep idea | grep -v "grep" | while read -r line; do
    # Extract the project directory from the process command
    projectDirectory=$(echo "$line" | awk -F "$launcherPath nosplash " '{print $2}' | awk '{print $1}')
    echo "$projectDirectory"

    # Kill the current IDEA process
    pid=$(echo "$line" | awk '{print $2}')
    kill -9 "$pid"

    # Restart IDEA with the extracted project directory
    nohup "$launcherPath" nosplash "$projectDirectory" > /dev/null 2>&1 &
done
