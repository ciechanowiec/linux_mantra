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

expectedLinuxReleaseName="resolute"
expectedMacReleaseName="macOS 27"

verifyOneArgument () {
  if [[ $# != 1 ]]
    then
      printf "%b The command should be provided with exactly one argument without whitespaces, which is the path to the existing folder to be opened in IntelliJ IDEA.\n" "${ERROR_TAG}"
      exit 1
  fi
}

verifyIfSpecifiedDirectoryExists () {
  requestedDirectory=$1
  if [[ ! -d "${requestedDirectory}" ]]
    then
      printf "%b The specified directory %b%s%b doesn't exist. Opening will be aborted.\n" "${ERROR_TAG}" "${ITALIC}" "${requestedDirectory}" "${RESET_FORMAT}"
      exit 1
  fi
}

idea() {
  projectDirectory=$1
  launcherPath=""

  linesWithLinuxReleaseName=0
  linesWithMacReleaseName=0
  command system_profiler -v &> /dev/null
  systemProfilerExitCode=$?
  if compgen -G "/etc/*-release" > /dev/null; # Checking a file existence with a glob pattern: https://stackoverflow.com/a/34195247
      then
        releaseFilesContent=$(cat /etc/*-release)
        linesWithLinuxReleaseName=$(grep --ignore-case --count "${expectedLinuxReleaseName}" <<< "${releaseFilesContent}")
    elif [[ "${systemProfilerExitCode}" -eq 1 ]]
      then
        softwareOverview=$(system_profiler SPSoftwareDataType)
        linesWithMacReleaseName=$(grep --ignore-case --count "${expectedMacReleaseName}" <<< "${softwareOverview}") # https://www.cyberciti.biz/faq/mac-osx-find-tell-operating-system-version-from-bash-prompt/
  fi
  if [[ "${linesWithLinuxReleaseName}" -gt 0 ]] && [[ "${linesWithMacReleaseName}" -gt 0 ]];
    then
      echo "Unexpected state: both supported operating systems detected, i.e. Mac and Linux. Exiting..."
      exit 1
    elif [[ "${linesWithLinuxReleaseName}" -gt 0 ]];
      then
        launcherPath="/snap/intellij-idea/current/bin/idea.sh"
    elif [[ "${linesWithMacReleaseName}" -gt 0 ]];
      then
        # Try Homebrew path first
        launcherPath="/opt/homebrew/bin/idea"
        # If Homebrew path is missing or a broken symlink, fallback to the Application bundle
        if [[ ! -f "${launcherPath}" ]]; then
          launcherPath="/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"
        fi
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  if [[ ! -f "${launcherPath}" ]]
    then
      printf "%b The IntelliJ IDEA launcher %b%s%b hasn't been detected. Opening will be aborted.\n" "${ERROR_TAG}" "${ITALIC}" "${launcherPath}" "${RESET_FORMAT}"
      exit 1
    else
      nohup "${launcherPath}" nosplash "${projectDirectory}" > /dev/null 2>&1 &
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
