#!/bin/bash
# A. Script for generating TypeScript projects from a template.
#    The template is fetched from a GitHub subdirectory using `degit`,
#    so the actual project files live in the template repo, not this script.
# B. Author: herman@ciechanowiec.eu.
# C. Table of Contents:
#    1. Formats
#    2. Functions
#    3. Configuration block
#    4. Driver code

# ============================================== #
#                                                #
#                    FORMATS                     #
#                                                #
# ============================================== #

BOLD="\e[1m"
BOLD_RED="\e[1;91m"
BOLD_LIGHT_CYAN="\e[1;96m"
BOLD_LIGHT_YELLOW="\e[1;93m"
BOLD_LIGHT_GREEN="\e[1;92m"
ITALIC="\e[3m"
RESET_FORMAT="\e[0m"
ERROR_TAG="${BOLD_RED}[ERROR]:${RESET_FORMAT}"
STATUS_TAG="${BOLD_LIGHT_CYAN}[STATUS]:${RESET_FORMAT}"

# ============================================== #
#                                                #
#                   FUNCTIONS                    #
#                                                #
# ============================================== #

showWelcomeMessage () {
	printf "${BOLD}========================\n"
	printf "MANTRA TS SCRIPT STARTED\n"
	printf "========================${RESET_FORMAT}\n"
}

verifyIfTreeExists () {
	if ! type tree &> /dev/null
	then
		printf "${ERROR_TAG} 'tree' package which is required to run the script hasn't been detected. The script execution has been aborted.\n"
    exit
	fi
}

verifyIfGitExists () {
	if ! type git &> /dev/null
	then
		printf "${ERROR_TAG} 'git' package which is required to run the script hasn't been detected. The script execution has been aborted.\n"
		exit
	fi
}

verifyIfNpxExists () {
	if ! type npx &> /dev/null
	then
		printf "${ERROR_TAG} 'npx' (Node.js) which is required to fetch the template via degit hasn't been detected. The script execution has been aborted.\n"
		exit
	fi
}

verifyIfPnpmExists () {
	if ! type pnpm &> /dev/null
	then
		printf "${ERROR_TAG} 'pnpm' which is required to install project dependencies hasn't been detected. The script execution has been aborted.\n"
		exit
	fi
}

verifyIfExactlyOneArgument () {
	if [ $# != 1 ]
	then
    printf "${ERROR_TAG} The script must be provided with exactly one argument: the project name. This condition hasn't been met and the script execution has been aborted.\n"
		exit
	fi
}

verifyIfCorrectPathUntilProjectDirectory () {
  pathUntilProjectDirectory=$1
	if [[ ! "$pathUntilProjectDirectory" =~ ^\/.* ]] || [ ! -d "$pathUntilProjectDirectory" ]
	then
		printf "${ERROR_TAG} Misconfigured path where the project directory should be created. That should be an absolute path for the existing directory. The script execution has been aborted.\n"
		exit
	fi
}

verifyIfCorrectProjectName () {
  projectName=$1
	if [[ ! "$projectName" =~ ^[a-z]{1}([a-z0-9-]*)$ ]]
	then
		printf "${ERROR_TAG} The provided project name may consist only of lower case ASCII letters, numbers and dashes. The first character should be an ASCII letter. This condition hasn't been met and the script execution has been aborted.\n"
		exit
	fi
}

verifyIfProjectPathIsFree () {
  projectDirectory=$1
	if [ -d "$projectDirectory" ]
	then
		printf "${ERROR_TAG} The specified project path is occupied: ${ITALIC}$projectDirectory${RESET_FORMAT}. The script execution has been aborted.\n"
		exit
	fi
}

bootstrapFromTemplate () {
  projectDirectory=$1
  templateRepoPath=$2
	printf "${STATUS_TAG} Fetching template from ${ITALIC}${templateRepoPath}${RESET_FORMAT} via degit...\n"
	if ! npx --yes degit "$templateRepoPath" "$projectDirectory" > /dev/null 2>&1
	then
		printf "${ERROR_TAG} Unable to fetch the template via degit. The script execution has been aborted.\n"
		exit 1
	fi
	printf "${STATUS_TAG} The project directory ${ITALIC}$projectDirectory${RESET_FORMAT} has been created from the template.\n"
}

substituteProjectName () {
  projectDirectory=$1
  projectName=$2
  packageJsonFile="$projectDirectory/package.json"
  readmeFile="$projectDirectory/README.md"
	if [ -f "$packageJsonFile" ]
	then
		sed "s/\"typescript-template\"/\"$projectName\"/" "$packageJsonFile" > "$packageJsonFile.tmp" && mv "$packageJsonFile.tmp" "$packageJsonFile"
		printf "${STATUS_TAG} Project name has been set in ${ITALIC}package.json${RESET_FORMAT}.\n"
	fi
	if [ -f "$readmeFile" ]
	then
		sed "s/^# TypeScript Template$/# $projectName/" "$readmeFile" > "$readmeFile.tmp" && mv "$readmeFile.tmp" "$readmeFile"
		printf "${STATUS_TAG} Project name has been set in ${ITALIC}README.md${RESET_FORMAT}.\n"
	fi
}

addLicense () {
  projectDirectory=$1
  gitCommitterName=$2
  gitCommitterSurname=$3
  licenseFile="$projectDirectory/LICENSE.txt"
  year=$(date +%Y)
  touch "$licenseFile"
cat > "$licenseFile" << EOF
The program is subject to MIT No Attribution License

Copyright © $year $gitCommitterName $gitCommitterSurname

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

The Software is provided 'as is', without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the use or other dealings in the Software.
EOF
printf "${STATUS_TAG} ${ITALIC}LICENSE.txt${RESET_FORMAT} with default content has been created.\n"
}

installDependencies () {
	projectDirectory=$1
	printf "${STATUS_TAG} Installing project dependencies via pnpm (this may take a moment)...\n"
	currentDirectory=$(pwd)
	cd "$projectDirectory" || exit 1
	if ! pnpm install > /dev/null 2>&1
	then
		printf "${ERROR_TAG} Unable to install project dependencies via pnpm. The script execution has been aborted.\n"
		cd "$currentDirectory" || exit 1
		exit 1
	fi
	cd "$currentDirectory" || exit 1
	printf "${STATUS_TAG} Project dependencies have been installed.\n"
}

initGit () {
	projectDirectory=$1
	git init "$projectDirectory" &> /dev/null   # Redirect to void hints on git initialization
	printf "${STATUS_TAG} Git repository has been initialized.\n"
}

setupGitCommitter () {
	projectDirectory=$1
	gitCommitterName=$2
	gitCommitterSurname=$3
	gitCommitterEmail=$4
	currentDirectory=$(pwd)
	cd "$projectDirectory" || exit 1
	git config user.name "$gitCommitterName $gitCommitterSurname"
	git config user.email $gitCommitterEmail
	printf "${STATUS_TAG} Git committer for this project has been set up: $gitCommitterName $gitCommitterSurname <$gitCommitterEmail>.\n"
	cd "$currentDirectory" || exit 1
}

initCommit() {
	projectDirectory=$1
  cd "$projectDirectory" || exit 1
  git add . > /dev/null 2>&1
  git commit -m "Init commit" > /dev/null 2>&1
	printf "${STATUS_TAG} Git init commit was made.\n"
}

showFinishMessage () {
	projectName=$1
	printf "${BOLD_LIGHT_GREEN}[SUCCESS]:${RESET_FORMAT} The project ${ITALIC}$projectName${RESET_FORMAT} with the following file structure has been created:\n"
  tree --dirsfirst -a -L 2 "$projectDirectory"
}

openProjectInIDE () {
  projectDirectory=$1
  launcherPath=""

  linesWithLinuxReleaseName=0
  linesWithMacReleaseName=0
  if compgen -G "/etc/*-release" > /dev/null;
      then
        linesWithLinuxReleaseName=$(cat /etc/*-release | grep --ignore-case --count "$expectedLinuxReleaseName")
    elif [ "$(command system_profiler -v &> /dev/null ; echo $?)" -eq 1 ]
      then
        linesWithMacReleaseName=$(system_profiler SPSoftwareDataType | grep --ignore-case --count "$expectedMacReleaseName")
  fi
  if [ "$linesWithLinuxReleaseName" -gt 0 ] && [ "$linesWithMacReleaseName" -gt 0 ];
    then
      echo "Unexpected state: both supported operating systems detected, i.e. Mac and Linux. Exiting..."
      exit 1
    elif [ "$linesWithLinuxReleaseName" -gt 0 ];
      then
        launcherPath="/snap/intellij-idea/current/bin/idea.sh"
    elif [ "$linesWithMacReleaseName" -gt 0 ];
      then
        # Try Homebrew path first
        launcherPath="/opt/homebrew/bin/idea"
        # If Homebrew path is missing or a broken symlink, fallback to the Application bundle
        if [ ! -f "$launcherPath" ]; then
          launcherPath="/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"
        fi
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  printf "${BOLD_LIGHT_YELLOW}[IntelliJ IDEA]:${RESET_FORMAT} Opening the project...\n"
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
#              CONFIGURATION BLOCK               #
#                                                #
# ============================================== #

# Revise and change values of the variables below to meet your needs
expectedLinuxReleaseName="resolute"
expectedMacReleaseName="macOS 26"
gitCommitterName="Herman"
gitCommitterSurname="Ciechanowiec"
gitCommitterEmail="herman@ciechanowiec.eu"
templateRepoPath="ciechanowiec/linux_mantra/resources/typescript_template"
pathUntilProjectDirectory="${HOME}/0_prog" # This directory must exist when script is executed

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

showWelcomeMessage
verifyIfTreeExists
verifyIfGitExists
verifyIfNpxExists
verifyIfPnpmExists
verifyIfExactlyOneArgument "$@"

projectName=$1 # First passed argument
projectDirectory="$pathUntilProjectDirectory/$1"
verifyIfCorrectPathUntilProjectDirectory "$pathUntilProjectDirectory"
verifyIfCorrectProjectName "$projectName"
verifyIfProjectPathIsFree "$projectDirectory"

# Fetch template from GitHub:
bootstrapFromTemplate "$projectDirectory" "$templateRepoPath"

# Customize template content:
substituteProjectName "$projectDirectory" "$projectName"
addLicense "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname"

# Install dependencies (must happen before initCommit so pnpm-lock.yaml is captured,
# and before openProjectInIDE so the Biome LSP finds its binary on first start):
installDependencies "$projectDirectory"

# Setup git:
initGit "$projectDirectory"
setupGitCommitter "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname" "$gitCommitterEmail"
initCommit "$projectDirectory"

# Finish:
showFinishMessage "$projectName"
openProjectInIDE "$projectDirectory"
