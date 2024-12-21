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

expectedLinuxReleaseName="jammy"
expectedMacReleaseName="macOS 15"

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
      printf "${ERROR_TAG} The specified directory ${ITALIC}${requestedDirectory}${RESET_FORMAT} doesn't exist. Opening will be aborted.\n"
      exit 1
  fi
}

idea() {
  projectDirectory=$1
  launcherPath=""

  linesWithLinuxReleaseName=0
  linesWithMacReleaseName=0
  if compgen -G "/etc/*-release" > /dev/null; # Checking a file existence with a glob pattern: https://stackoverflow.com/a/34195247
      then
        linesWithLinuxReleaseName=$(cat /etc/*-release | grep --ignore-case --count "$expectedLinuxReleaseName")
    elif [ "$(command system_profiler -v &> /dev/null ; echo $?)" -eq 1 ]
      then
        linesWithMacReleaseName=$(system_profiler SPSoftwareDataType | grep --ignore-case --count "$expectedMacReleaseName") # https://www.cyberciti.biz/faq/mac-osx-find-tell-operating-system-version-from-bash-prompt/
  fi
  if [ "$linesWithLinuxReleaseName" -gt 0 ] && [ "$linesWithMacReleaseName" -gt 0 ];
    then
      echo "Unexpected state: both supported operating systems detected, i.e. Mac and Linux. Exiting..."
      exit 1
    elif [ "$linesWithLinuxReleaseName" -gt 0 ];
      then
        launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"
#        launcherPath="/snap/intellij-idea-community/current/bin/idea.sh"
    elif [ "$linesWithMacReleaseName" -gt 0 ];
      then
        launcherPath="/opt/homebrew/bin/idea"
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  if [ ! -f "$launcherPath" ]
    then
      printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
      exit 1
    else
      nohup "$launcherPath" nosplash "$projectDirectory" > /dev/null 2>&1 &
  fi
}

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

verifyOneArgument "$@"
verifyIfSpecifiedDirectoryExists "$@"
idea "$1"
