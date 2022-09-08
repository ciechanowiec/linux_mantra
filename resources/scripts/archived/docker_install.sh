#!/bin/bash

# ============================================== #
#                                                #
#                  SCRIPT SETUP                  #
#                                                #
# ============================================== #

# Directories
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
tempDir="${HOME}/.temp"
currentDir=$(pwd)
# Formats
boldRed="\e[1;91m"
boldBlue="\e[1;34m"
resetFormat="\e[0m"
# Functions
printProcessMessage () {
  message=$1
  printf "${boldBlue}${message}${resetFormat}\n"
}
printCustomErrorAndExit () {
  errorMessageContent=$1
  errorMessage="${boldRed}${errorMessageContent}${resetFormat}\n"
  exitMessage="${boldRed}EXITING THE SCRIPT...${resetFormat}\n"
  printf "${errorMessage}"
  printf "${exitMessage}\n"
  exit 1
}
printInvalidDirErrorAndExit () {
  errorMessage="${boldRed}Error during directory manipulation occurred${resetFormat}"
  exitMessage="${boldRed}EXITING THE SCRIPT...${resetFormat}\n"
  printf "${errorMessage}"
  printf "${exitMessage}\n"
  exit 1
}
# Go to a temporary directory
printProcessMessage "Going to the temporary directory where the
    installation will be performed ($tempDir)..."
if [ -d $tempDir ]
then
  cd "$tempDir" || printInvalidDirErrorAndExit
else
  mkdir "$tempDir"
  cd "$tempDir" || printInvalidDirErrorAndExit
fi

# ============================================== #
#                                                #
#              CHECK PREREQUISITES               #
#                                                #
# ============================================== #

printProcessMessage "\nPREREQUISITES CHECK..."

actualLinuxRelease=$(lsb_release -i)

if ! command curl --version &> /dev/null
then
		printCustomErrorAndExit "Error: 'curl' package isn't installed"

elif [[ ! "$actualLinuxRelease" == *"Ubuntu"* ]]
then
    printCustomErrorAndExit "Error: Linux 'Ubuntu' distribution is required"
fi

printProcessMessage "Check was successful"

# ============================================== #
#                                                #
#                    DOCKER                      #
#                                                #
# ============================================== #

printProcessMessage "\nINSTALLING DOCKER..."

printProcessMessage "Removing old Docker versions..."
sudo apt remove docker docker-engine docker.io containerd runc -y
sudo snap remove docker

printProcessMessage "Installing Docker..."
sudo snap install docker

printProcessMessage "Initializing Docker..."
sleep 7

printProcessMessage "Setting Docker to be run without 'sudo' prefix..."
sudo groupadd docker
sudo usermod -aG docker $USER
# To run Docker without 'sudo' prefix, the reboot after the above commands is required.
# However, it is possible to test without the reboot whether Docker without 'sudo' prefix
# can be run. In order to do that, the 'newgrp docker' command should be executed.
# By default, the 'newgrp docker' command will terminate the script. To prevent it,
# it is needed to use a heredoc code block as shown below, where it is tested
# whether Docker without 'sudo' prefix can be run. However, that 'newgrp docker'
# command has only local effect for one session of the terminal. To run Docker without
# 'sudo' prefix globally, reboot is required, as mentioned above
newgrp docker << EOF
printf "${boldBlue}Running 'hello-world' Docker image to test installation...${resetFormat}\n"
docker run hello-world
EOF

printProcessMessage "Docker successfully installed"

# ============================================== #
#                                                #
#                DOCKER COMPOSE                  #
#                                                #
# ============================================== #

# The installation process below is performed according to the following instructions:
# https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04

printProcessMessage "\nINSTALLING DOCKER COMPOSE..."

printProcessMessage "Removing old Docker Compose versions..."
sudo rm -rf /usr/local/bin/docker-compose

printProcessMessage "Retrieving information about the latest Docker Compose version..."
# The code below:
# 1. Retrieves the source code of the webpage with latest Docker Compose releases:
# https://github.com/docker/compose/releases
# 2. Extracts from the retrieved data a list of latest Docker Compose releases
# (the information about the latest Docker Compose releases originally come from lines like
# <h1 data-view-component="true" class="d-inline mr-3"><a href="/docker/compose/releases/tag/v2.5.1" data-view-component="true" class="Link--primary">v2.5.1</a>)
# 3. Chooses the first line from the extracted list of latest Docker
# Compose releases, i.e. the line with the latest Docker Compose release
latestDockerRelease=$(sudo curl https://github.com/docker/compose/releases \
	| grep -oP '(?<=/docker/compose/releases/tag/).*(?=" data)' \
	| head -1)

printProcessMessage "Now the latest (${latestDockerRelease}) Docker Compose release will be downloaded and
    saved as executable file at /usr/local/bin/docker-compose, which
    will make this software globally accessible as 'docker-compose'..."
sudo curl -L "https://github.com/docker/compose/releases/download/${latestDockerRelease}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

printProcessMessage "Setting the correct permissions so that the 'docker-compose' command is executable..."
sudo chmod +x /usr/local/bin/docker-compose

printProcessMessage "Checking Docker Compose installation..."
actualDCVersion=$(docker-compose -v)
if [[ "$actualDCVersion" == *"$latestDockerRelease"* ]]
then
  printProcessMessage "Docker Compose successfully installed"
else
  printCustomErrorAndExit "Error during Docker Compose installation occurred"
fi

# ============================================== #
#                                                #
#                    CLEAN UP                    #
#                                                #
# ============================================== #

printProcessMessage "\nCLEANING UP..."

printProcessMessage "Going back to the working directory ($currentDir)..."
cd "$currentDir" || exitBecauseInvalidDir
