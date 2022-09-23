#!/bin/bash

baseName=$(basename -- "$1")
archiveName="$baseName.zip"

if [ $# != 1 ]
  then
    echo "Invalid arguments. Exactly one argument required for the command: path of the baseName to be archived"
elif [ ! -d "$baseName" ]
  then
    echo "Only existing directories can be archived"
elif [ -d "$archiveName" ] || [ -f "$archiveName" ]
  then
    echo "Directory/file '$archiveName' already exists"
  else
    zip -r "$archiveName" "$baseName"
fi
