#!/bin/bash

# ============================================== #
#                                                #
#                   FUNCTIONS                    #
#                                                #
# ============================================== #

BOLD_RED="\e[1;91m"
ITALIC="\e[3m"
RESET_FORMAT="\e[0m"
ERROR_TAG="${BOLD_RED}[ERROR]:${RESET_FORMAT}"

# Version for IntelliJ IDEA Community:
#launcherPath="/snap/intellij-idea-community/current/bin/idea.sh"
# Version for IntelliJ IDEA Ultimate:
launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"

verifyIfLauncherExists () {
  if [ ! -f "$launcherPath" ]
    then
      printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT}hasn't been detected. Opening will be aborted.\n"
      exit 1
  fi
}

verifyOneArgument () {
  if [ $# != 1 ]
    then
      printf "${ERROR_TAG} The command should be provided with exactly one argument without whitespaces, which is the path to the existing folder to be opened in IntelliJ IDEA.\n"
      exit 1
  fi
}

verifyIfSpecifiedDirectoryExists () {
  requestedDirectory=$1
  if [ ! -d "$requestedDirectory" ]
    then
      printf "${ERROR_TAG} The specified directory ${ITALIC}${requestedDirectory}${RESET_FORMAT}doesn't exist. Opening will be aborted.\n"
      exit 1
  fi
}

idea() {
  specifiedFolder=$1
  nohup "$launcherPath" nosplash "$specifiedFolder" > /dev/null 2>&1 &
}

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

verifyIfLauncherExists
verifyOneArgument "$@"
verifyIfSpecifiedDirectoryExists "$@"
idea "$@"
