#!/bin/bash

latestConditional=$(curl -s https://api.github.com/repos/ciechanowiec/conditional/releases/latest | grep 'tag_name' | sed 's/^ *//g' | sed 's/ *$//g' | cut -d ' ' -f 2 | sed 's/["v,]*//g')
latestConditionalLines=$(echo "$latestConditional" | wc -l)
latestConditionalChars=$(echo "$latestConditional" | wc -m)

if [ "$latestConditionalLines" != "1" ] || [ "$latestConditionalChars" -le 1 ]
  then
    echo "Error. Couldn't retrieve the latest version of Conditional library. Aborting..."
    rm -rf "$projectDirectory"
    exit 1
fi
