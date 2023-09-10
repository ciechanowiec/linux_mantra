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
expectedMacReleaseName="macOS 13"
# It is assumed that the project will be opened in IntelliJ IDEA Ultimate.
# In case you want to use IntelliJ IDEA Community, comment out the code line below
# and restore from the comment the next line:
launcherPathLinux="/snap/intellij-idea-ultimate/current/bin/idea.sh"
#launcherPathLinux="/snap/intellij-idea-community/current/bin/idea.sh"
launcherPathMac="$HOME/Applications/IntelliJ IDEA.app"

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
  launcherPathLinux=$1
  launcherPathMac=$2
  projectDirectory=$3
  launcherPath=""

  isMacOS=false
  isLinux=false
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
        isLinux=true
        launcherPath="$launcherPathLinux"
    elif [ "$linesWithMacReleaseName" -gt 0 ];
      then
        isMacOS=true
        launcherPath="$launcherPathMac"
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
    then
        if [ ! -f "$launcherPath" ]
          then
            printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
            exit 1
          else
            nohup "$launcherPathLinux" nosplash "$projectDirectory" > /dev/null 2>&1 &
        fi
    elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
      then
        if [ ! -d "$launcherPath" ]
          then
            printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
            exit 1
          else
            open -na "IntelliJ IDEA.app" --args "$projectDirectory" nosplash
        fi
    else
      echo "Unexpected error occurred. Launching failed"
      exit 1
  fi
}

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

verifyOneArgument "$@"
verifyIfSpecifiedDirectoryExists "$@"
idea "$launcherPathLinux" "$launcherPathMac" "$1"
