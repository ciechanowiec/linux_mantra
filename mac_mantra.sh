#!/bin/bash

###############################################################################
#                                                                             #
#                                                                             #
#                       COMMON FUNCTIONS AND VARIABLES                        #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="null"

informAboutProcedureStart() {
  printf "\nPROCEDURE STARTED: $procedureId\n"
}

informAboutProcedureEnd() {
  printf "PROCEDURE FINISHED: $procedureId\n"
}

promptOnContinuation() {
  echo ""
  while true; do
    read -p "Proceed? [Y/n] " answer
    case $answer in
      [yY] )
        printf "Proceeding...\n"
        break;;
      "" )
        printf "Proceeding...\n"
        break;;
      [nN] )
        echo "Exiting..."
        exit 0;;
      * )
        printf "Invalid input. Try again.\n";;
    esac
  done
}

###############################################################################
#                                                                             #
#                                                                             #
#                         1. ENVIRONMENT PREPARATION                          #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="environment preparation"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Setting up variables..."
initialWorkingDirectory=$(pwd)
originalScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
resourcesDir="$originalScriptDir/resources"
tempDir="$HOME/TEMP"
osType="null"
shellFile="null"
isMacOS=false
isLinux=false
expectedLinuxReleaseName="jammy"
expectedMacReleaseName="macOS 15"

echo "2. Checking whether the resources directory exists..."
if [ ! -d "$resourcesDir" ]
  then
    echo "Resources directory doesn't exist ($resourcesDir). Exiting..."
    exit 1;
fi

echo "3. Establishing a working directory where Mantra will be executed..."
if [ -d "$tempDir" ]
  then
    echo "Detected $tempDir. Removing..."
    rm -rf "$tempDir"
fi
echo "3.1. Creating $tempDir as a working directory..."
mkdir -p "$tempDir"

echo "3.2. Going to the working directory $tempDir..."
cd "$tempDir" || exit 1

echo "4. Resolving the operating system..."
linesWithLinuxReleaseName=0
linesWithMacReleaseName=0
if compgen -G "/etc/*-release" > /dev/null; # Checking a file existence with a glob pattern: https://stackoverflow.com/a/34195247
    then
      echo "Linux check will be performed..."
      linesWithLinuxReleaseName=$(cat /etc/*-release | grep --ignore-case --count "$expectedLinuxReleaseName")
	elif [ "$(command system_profiler -v &> /dev/null ; echo $?)" -eq 1 ]
	  then
      echo "macOS check will be performed..."
      linesWithMacReleaseName=$(system_profiler SPSoftwareDataType | grep --ignore-case --count "$expectedMacReleaseName") # https://www.cyberciti.biz/faq/mac-osx-find-tell-operating-system-version-from-bash-prompt/
fi
if [ "$linesWithLinuxReleaseName" -gt 0 ] && [ "$linesWithMacReleaseName" -gt 0 ];
  then
    echo "Unexpected state: both supported operating systems detected, i.e. Mac and Linux. Exiting..."
    exit 1
  elif [ "$linesWithLinuxReleaseName" -gt 0 ];
    then
      echo "Linux release detected"
      isLinux=true
      osType="linux"
      shellFile="$HOME/.bashrc"
  elif [ "$linesWithMacReleaseName" -gt 0 ];
    then
      echo "macOS release detected"
      isMacOS=true
      osType="mac"
      shellFile="$HOME/.zshrc"
  else
    echo "Unsupported operating system. Exiting..."
    exit 1;
fi

echo "5. Updating the operating system..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    echo "5.1. Downloading packages information from all configured sources..."
    sudo apt update -y
    echo "5.2. Installing available upgrades of all packages currently installed on the system..."
    sudo apt upgrade -y
    echo "5.3. Removing unnecessary dependencies..."
    sudo apt autoremove -y
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      softwareupdate --verbose --install --all
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         2. MACOS DEVELOPER TOOLS                            #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="macos developer tools"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Without this some developer tools might not work as expected on macOS

informAboutProcedureStart

clt_installed() {
    pkgutil --pkg-info=com.apple.pkg.CLTools_Executables &> /dev/null
}
echo "Checking if macOS developer tools, including git, are installed..."
if clt_installed && git --version &> /dev/null; then
    echo "macOS developer tools, including git, are installed"
    git --version
else
    echo -e "Installing macOS developer tools, including git. \033[1mConfirm installation in pop-up windows if requested...\033[0m"
    xcode-select --install > /dev/null 2>&1
    echo "Waiting for macOS developer tools, including git, installation to complete..."
    until clt_installed && git --version &> /dev/null; do
        sleep 5
    done
    echo "macOS developer tools, including git, were installed successfully"
    git --version
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  3. SHELL                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="shell"
# DOCUMENTATION:
#   https://github.com/ohmyzsh/ohmyzsh/wiki

informAboutProcedureStart

echo "1. Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "2. Changing terminal prompt..."
# Final prompt should be: PS1='%B$fg[green]%~$reset_color%b'$'\n''❯ '
cat >> "$shellFile" << EOF

# ADJUSTING TERMINAL PROMPT:
PS1='%B\$fg[green]%~\$reset_color%b'$'\n''❯ '
EOF

echo "3. Disabling auto title..."
sed -i.backup "s/# DISABLE_AUTO_TITLE/DISABLE_AUTO_TITLE/g" "$shellFile"

echo "4. Adjusting plugins..."
sed -i.backup "s/plugins=(git)/plugins=(git web-search)/g" "$shellFile"

echo "5. Fixing an autocompletion bug..."
# https://stackoverflow.com/a/22779469
cat >> "$shellFile" << EOF

# FIXING AUTOCOMPLETION BUG:
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
EOF

echo "6. Making * to include hidden files..."
# Details on the change: https://unix.stackexchange.com/a/6397
cat >> "$shellFile" << EOF

# MAKING * TO INCLUDE HIDDEN FILES:
setopt dot_glob
EOF

echo "7. Adding user binaries to path..."
cat >> "$shellFile" << EOF

# ADDING USER BINARIES TO PATH:
export PATH="/usr/local/bin:$PATH"
EOF

echo "8. Copying bash scripts..."
sourceDirWithScripts="$resourcesDir/scripts"
targetDirWithScripts="$HOME/scripts"
mkdir -p "$targetDirWithScripts"
cp -f "$sourceDirWithScripts"/* "$targetDirWithScripts"

echo "9.1. Setting up UNIX aliases..."
cat >> "$shellFile" << EOF

# UNIX ALIASES:
alias aem_init_archetype_65='~/scripts/aem_init_archetype.sh 65'
alias aem_init_archetype_cloud='~/scripts/aem_init_archetype.sh cloud'
alias docker_clean='~/scripts/docker_clean.sh'
alias docker_clean_containers='~/scripts/docker_clean_containers.sh'
alias docker_clean_images='~/scripts/docker_clean_images.sh'
alias docker_clean_networks='~/scripts/docker_clean_networks.sh'
alias docker_clean_volumes='~/scripts/docker_clean_volumes.sh'
alias git_clip_cur_branch="git branch | grep '*' | cut -d ' ' -f 2 | xxclip"
alias git_switch_to_com='~/scripts/git_switch_to_com.sh'
alias i='idea'
alias idea='~/scripts/idea.sh'
alias mantra_java='~/scripts/mantra_java.sh'
alias mantra_spring_mongo='~/scripts/mantra_spring_mongo.sh'
alias mantra_spring_sql='~/scripts/mantra_spring_sql.sh'
alias mvn_download_sources_and_javadocs='mvn dependency:sources && mvn dependency:sources dependency:resolve -Dclassifier=javadoc'
alias n='nvim'
alias nvim="~/scripts/nvim.sh"
alias x='xplr'
alias xplr='~/scripts/xplr.sh'
EOF

echo "9.2. Setting up Mac aliases..."
cat >> "$shellFile" << EOF

# MAC ALIASES:
alias colima_scp_from_host_to_vm='~/scripts/colima_scp_from_host_to_vm.sh'
alias colima_scp_from_vm_to_host='~/scripts/colima_scp_from_vm_to_host.sh'
alias colima_ssh='~/scripts/colima_ssh.sh'
# Convert "docker compose" to "docker-compose":
docker() {
   if [ "\$1" = "compose" ]; then
       shift
       command docker-compose "\$@"
   else
       command docker "\$@"
   fi
}
alias e='edge'
alias edge='open -a "Microsoft Edge"'
fuse() {
    if [ -z "$1" ]; then
        echo "Usage: fuse <port>"
        return 1
    fi
    local pids
    pids=$(lsof -ti tcp:"$1")
    if [ -n "$pids" ]; then
        echo "Killing processes on port $1:"
        echo "$pids" | while read -r pid; do
            kill -9 "$pid" && echo "Killed process $pid"
        done
    else
        echo "No process found on port $1"
    fi
}
alias ir='( nohup ~/scripts/idea_restart.sh >/dev/null 2>&1 & )'
alias logout="launchctl reboot logout" # https://apple.stackexchange.com/a/450798
alias reboot="sudo shutdown -r now"
alias shutdown="sudo shutdown -h now"
alias sleep="sudo pmset sleepnow"
alias xxclip="perl -pe 'chomp if eof' | pbcopy" # perl is required to drop the last NL character
EOF

echo "10. Disable '%' sign in the end of output..."
# Docs: https://stackoverflow.com/a/54776364
cat >> "$shellFile" << EOF

# DISABLE '%' SIGN IN THE END OF OUTPUT:
# Docs: https://stackoverflow.com/a/54776364
export PROMPT_EOL_MARK=''
EOF

echo "11. Disable 'Last login...' hint on the terminal start..."
touch "$HOME/.hushlogin"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         4.1. NIX PACKAGE MANAGER                            #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="nix package manager"
# DOCUMENTATION:
#   https://nixos.org/download.html
# NOTES:
#   In general, nix isn't a good and convenient tool. Avoid its usage

informAboutProcedureStart

if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    echo "Installing nix package manager..."
    yes | sh <(curl -L https://nixos.org/nix/install) --daemon
    echo "Sourcing nix package manager from /etc/bashrc..."
    sleep 3
    source /etc/bashrc
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      echo "Installing nix package manager..."
      yes | sh <(curl -L https://nixos.org/nix/install)
      echo "Sourcing nix package manager from /etc/zshrc..."
      sleep 3
      source /etc/zshrc
  else
    echo "Unexpected error occurred. The requested action wasn't preformed correctly"
    exit 1
fi

echo "Updating nix channels..."
nix-channel --update # In some cases without this command the nix-env might not work correctly

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                      4.2. HOMEBREW PACKAGE MANAGER                          #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="homebrew package manager"
# DOCUMENTATION:
#   https://brew.sh/
#   https://docs.brew.sh/Homebrew-on-Linux
#   https://docs.brew.sh/Shell-Completion
#   https://www.digitalocean.com/community/tutorials/how-to-install-and-use-homebrew-on-linux
# NOTES:
#    By default, `homebrew`, which is executed via the command `brew`, isn't added permanently to the PATH.
#    For that reason, in order to have it on the PATH and be able to execute the `brew` command,
#    after `homebrew` installation, it should be added to the PATH. Note that ways of doing it described in
#    official documentation and in almost all tutorials doesn't work. In fact, it should be achieved via the
#    commands used below in the script.

informAboutProcedureStart

echo "1. Installing compiler environment if this is Linux..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    sudo apt install build-essential -y
fi

echo "2. Installing homebrew..."
sudo yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "3. Making brew executable..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
cat >> "$shellFile" << EOF

# 'brew' COMMAND:
export PATH="\$PATH:/home/linuxbrew/.linuxbrew/bin"
eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
if type brew &>/dev/null; then # autocompletion
	HOMEBREW_PREFIX="\$(brew --prefix)"
	if [[ -r "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
		source "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
	else
		for COMPLETION in "\${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
			[[ -r "\${COMPLETION}" ]] && source "\${COMPLETION}"
		done
	fi
fi
EOF
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" # For the current shell
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
cat >> "$shellFile" << EOF

# 'brew' COMMAND:
eval "\$(/opt/homebrew/bin/brew shellenv)"
if type brew &>/dev/null # autocompletion
  then
    FPATH="\$(brew --prefix)/share/zsh/site-functions:\${FPATH}"

    autoload -Uz compinit
    compinit
fi
EOF
eval "$(/opt/homebrew/bin/brew shellenv)" # For the current shell
  else
    echo "Unexpected error occurred. The requested action wasn't preformed correctly"
    exit 1
fi

if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    echo "4. Evaluating the shell..."
    source "$shellFile"
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               4.3. ROSETTA                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="rosetta"
# DOCUMENTATION:
#   https://apple.stackexchange.com/questions/408375/zsh-bad-cpu-type-in-executable
#   https://www.hexnode.com/mobile-device-management/help/script-to-install-rosetta-2-on-mac-devices-with-apple-silicon/
# NOTES:
#   Allows to run apps with Intel CPU architecture on macOS with ARM CPU architecture

informAboutProcedureStart

echo "Installing Rosetta if this is macOS"
if [ "$isLinux" == false ] && [ "$isMacOS" == true ];
 then
   softwareupdate --install-rosetta --agree-to-license
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              5. TERRAFORM                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="terraform"
# DOCUMENTATION:
#   https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli
# NOTES:
#   On Linux it is easier to install terraform as described for MacOS, i.e. with homebrew

echo "1. Installing Terraform..."
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew upgrade hashicorp/tap/terraform
touch "$shellFile"

echo "2. Enabling Terraform autocompletion..."
cat >> "$shellFile" << EOF

# TERRAFORM AUTOCOMPLETION:
EOF
terraform -install-autocomplete

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             5. AZURE CLI                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="azure cli"
# DOCUMENTATION:
#   https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos

echo "1. Installing Azure CLI..."
brew update && brew install azure-cli

echo "2. Enabling Azure CLI autocompletion..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
 then
cat >> "$shellFile" << EOF

# AZURE CLI AUTOCOMPLETION:
source /home/linuxbrew/.linuxbrew/etc/bash_completion.d/az
EOF
 elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
   then
cat >> "$shellFile" << EOF

# AZURE CLI AUTOCOMPLETION:
# (https://stackoverflow.com/questions/49273395/how-to-enable-command-completion-for-azure-cli-in-zsh):
autoload -U +X bashcompinit && bashcompinit
source /opt/homebrew/etc/bash_completion.d/az
EOF
 else
   echo "Unexpected error occurred. Update failed"
   exit 1
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                6. SDKMAN                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="sdkman"
# DOCUMENTATION:
#   https://sdkman.io/install
# NOTES:
#   SDKMAN's entries in shell files (SDKMAN appends new lines to the bottom of `.bashrc`/`.zshrc`
#   file automatically during installation) must be located on the last lines of `.bashrc`/`.zshrc` file

echo "1. Installing SDKMAN..."
curl -s "https://get.sdkman.io" | bash
sleep 3 # Required for the above command to be fully completed

echo "2. Sourcing SDKMAN..."
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               6.1. JAVA                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="java"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Regularly check if there are new versions of installed JDKs

informAboutProcedureStart

echo "Sourcing sdk command..."
# For an unknown reason, without the following sourcing, sdk command might not be recognized:
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "Installing Java 8..."
# Java 8 Temurin release might be unavailable for macOS, so Zulu is installed:
yes | sdk install java 8.0.412-zulu

echo "Installing Java 11..."
yes | sdk install java 11.0.23-tem

echo "Installing Java 17..."
yes | sdk install java 17.0.11-tem

echo "Installing Java 21..."
yes | sdk install java 21.0.3-tem

echo "Installing Java 21 GraalVM..."
yes | sdk install java 21.0.2-graalce

echo "Setting Java 21 as the default one..."
sdk default java 21.0.3-tem

echo "Enabling the installed program in the current console..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                6.2. MAVEN                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="maven"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Regularly check if there is a new version of the installed program

informAboutProcedureStart

echo "Sourcing sdk command..."
# For an unknown reason, without this sourcing, sdk command might not be recognized:
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "Installing Maven..."
yes | sdk install maven 3.9.6

echo "Adding the Adobe Maven repository..."
# Details: 1. https://repo.adobe.com/index.html
#          2. https://redquark.org/aem/day-04-setup-aem-dev-environment/
mavenDir="$HOME/.m2"
if [ ! -d "$mavenDir" ]
  then
    mkdir -p "$mavenDir"
fi
mavenSettingsFile="$HOME/.m2/settings.xml"
touch "$mavenSettingsFile"
cat > "$mavenSettingsFile" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="https://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="https://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">
    <profiles>
        <!-- ====================================================== -->
        <!-- A D O B E   P U B L I C   P R O F I L E                -->
        <!-- ====================================================== -->
      <profile>
          <id>adobe-public</id>

          <activation>
              <activeByDefault>false</activeByDefault>
          </activation>

          <properties>
              <releaseRepository-Id>adobe-public-releases</releaseRepository-Id>
              <releaseRepository-Name>Adobe Public Releases</releaseRepository-Name>
              <releaseRepository-URL>https://repo.adobe.com/nexus/content/groups/public</releaseRepository-URL>
          </properties>

          <repositories>
              <repository>
                  <id>adobe-public-releases</id>
                  <name>Adobe Public Repository</name>
                  <url>https://repo.adobe.com/nexus/content/groups/public</url>
                  <releases>
                      <enabled>true</enabled>
                      <updatePolicy>never</updatePolicy>
                  </releases>
                  <snapshots>
                      <enabled>false</enabled>
                  </snapshots>
              </repository>
          </repositories>

          <pluginRepositories>
              <pluginRepository>
                  <id>adobe-public-releases</id>
                  <name>Adobe Public Repository</name>
                  <url>https://repo.adobe.com/nexus/content/groups/public</url>
                  <releases>
                      <enabled>true</enabled>
                      <updatePolicy>never</updatePolicy>
                  </releases>
                  <snapshots>
                      <enabled>false</enabled>
                  </snapshots>
              </pluginRepository>
          </pluginRepositories>
      </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>adobe-public</activeProfile>
    </activeProfiles>
</settings>
EOF

echo "Enabling the installed program in the current console..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             6.3. SPRING BOOT                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="spring boot"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Installed mainly for Spring Boot CLI

informAboutProcedureStart

echo "Sourcing sdk command..."
# For an unknown reason, without this sourcing, sdk command might not be recognized:
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "Installing Spring Boot..."
sdk install springboot

echo "Enabling the installed program in the current console..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              7. BASIC UTILS                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="basic utils"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Installing tree (list contents of directories in a tree-like format)..."
brew install tree

echo "Installing p7zip (file decompressor)..."
brew install p7zip

echo "Installing wget (non-interactive network downloader)..."
brew install wget

echo "Installing htop (interactive process viewer)..."
brew install htop

echo "Installing djvulibre (.djvu files viewer)..."
brew install djvulibre

echo "Installing mpv (media player)..."
brew install mpv

echo "Installing ffmpeg (audio/video converter)..."
brew install ffmpeg

echo "Installing trash-cli (CLI for removing files)..."
brew install pipx
pipx ensurepath
sudo pipx ensurepath --global # optional to allow pipx actions with --global argument
pipx install trash-cli
export PATH="$PATH:/Users/$(whoami)/.local/bin"

echo "Installing fzf (file finder)..."
brew install fzf

echo "Installing xclip (CLI-based clipboard selections)..."
brew install xclip

echo "Installing icdiff (tool for comparing files/directories)..."
brew install icdiff

echo "Installing jq (CLI JSON processor)..."
brew install jq

echo "Installing vale (syntax-aware linter for prose)..."
brew install vale

echo "Installing asciidoctor (asciidoc processor with extensions)..."
brew install asciidoctor

echo "Installing exiftool (read and write meta information in files)"
brew install exiftool

echo "Installing tesseract (command-line OCR engine)"
brew install tesseract

echo "Installing imagemagick (images converter)"
brew install imagemagick

echo "Installing yt-dlp (YouTube downloader)..."
# 1. Do not perform installation via other package managers - the program might not work correctly then
# 2. Do not perform installation with sudo - it might not - the program might not work correctly then
pip3 install yt-dlp --no-warn-script-location

echo "Installing postman (app for building and using APIs)..."
brew install postman

echo "installing node (server environment)..."
brew install node

echo "Installing TypeScript..."
# Installation docs:
#   bad: https://www.typescriptlang.org/download
#   good: https://lindevs.com/install-typescript-on-ubuntu
sudo npm install -g typescript # `npm` comes from node, so node must be preinstalled

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  8. GIT                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="git"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Setting up a global git committer..."
echo "Enter global git committer name (first name and surname, eg. John Doe):"
read committerName
echo "Enter global git committer email:"
read committerEmail
git config --global user.name "$committerName"
git config --global user.email "$committerEmail"

echo "2. Disabling pagination for branch listing..."
# Docs: https://stackoverflow.com/a/48370253
git config --global pager.branch false

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  9. ITERM2                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="iterm2"
# DOCUMENTATION:
#   https://iterm2.com/documentation.html
# NOTES:
#   1. This color theme is used:
#      https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Solarized%20Darcula.itermcolors
#   2. Remove last login initial line:
#      https://stackoverflow.com/a/16181082

informAboutProcedureStart

# Regularly review the current version (it is hardcoded now).
# In case of version change, update the plist configuration:
iTermInstallationArchive="iTerm2-3_5_10.zip"

echo "1. Downloading the iTerm2 archive..."
wget "https://iterm2.com/downloads/stable/$iTermInstallationArchive"

echo "2. Installing the iTerm application..."
iTermTempDir="$(pwd)/iTermTempDir"
if [ -d "$iTermTempDir" ]
 then
   echo "Detected $iTermTempDir. Removing..."
   trash-put "$iTermTempDir"
fi
mkdir -p "$iTermTempDir"
tar --extract --verbose --file "$iTermInstallationArchive" --directory "$iTermTempDir"
sudo cp -v -R "$iTermTempDir/iTerm.app" "$HOME/Applications"

echo "3. Writing defaults settings..."
iTermPlistRepoPath="$resourcesDir/mac/defaults/HOME/Library/Preferences/com.googlecode.iterm2.plist"
iTermPlistTempDirPath="$tempDir/com.googlecode.iterm2.plist"
iTermPlistOSPath="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
# Note that the plist settings should contain dynamic references to
# the current user. Therefore, maintenance and updates of those
# settings should go through the following cycle:
#   A. Copy active binary settings to the repository
#      (uncomment the code below during settings update):
#cp -f "$iTermPlistOSPath" "$iTermPlistRepoPath"
#   B. Convert the active binary settings to xml
#      (B.1. On plist <-> xml conversion: https://osxdaily.com/2016/03/10/convert-plist-file-xml-binary-mac-os-x-plutil/
#       B.2. Uncomment the code below during settings update):
#plutil -convert xml1 "$iTermPlistRepoPath"
#   C. Replace the actual username from the active xml settings with a generic one
#      (uncomment the code below during settings update):
#sed -i.backup "s|login -fpql .*/bin|login -fpql GENERICUSERNAME /bin|g" "$iTermPlistRepoPath"
#sed -i.backup "s|<string>/Users/.*</string>|<string>/Users/GENERICUSERNAME</string>|g" "$iTermPlistRepoPath"
#trash-put "${iTermPlistRepoPath}.backup"
#   D. The generified xml settings created above should be stored in the repository
#   E. Copy the generified xml settings from the repository to the temporary directory:
cp "$iTermPlistRepoPath" "$iTermPlistTempDirPath"
#   F. Replace the generic username in generified xml settings in
#      the temporary directory with a concrete one:
sed -i.backup "s|login -fpql .*/bin|login -fpql $(whoami) /bin|g" "$iTermPlistTempDirPath"
sed -i.backup "s|<string>/Users/.*</string>|<string>/Users/$(whoami)</string>|g" "$iTermPlistTempDirPath"
#   G. Convert the prepared xml settings into binary format
#      (on plist <-> xml conversion: https://osxdaily.com/2016/03/10/convert-plist-file-xml-binary-mac-os-x-plutil/):
plutil -convert binary1 "$iTermPlistTempDirPath"
#   H. Write the prepared binary settings to OS:
cp "$iTermPlistTempDirPath" "$iTermPlistOSPath"

echo "4. Setting up iTerm to be launched on startup in order to have the dropdown terminal working right after the startup..."
iTermPath="$HOME/Applications/iTerm.app"
# On login item adding: https://apple.stackexchange.com/a/310502
# On variables in the command below: https://stackoverflow.com/q/23923017
# The command below outputs 'login item UNKNOWN', which is ok: https://copyprogramming.com/howto/can-login-items-be-added-via-the-command-line-in-high-sierra?utm_content=cmp-true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$iTermPath"'", hidden:false}' > /dev/null

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                10. VIM                                      #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="vim"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Setting up vim as a default editor if this is Linux..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    sudo update-alternatives --set editor /usr/bin/vim.basic
fi

echo "2. Enabling cycling for {hjkl} vim keys if this is macOS..."
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    # Docs: https://stackoverflow.com/a/43340099
    defaults write -g ApplePressAndHoldEnabled -bool false
fi

echo "3. Updating .vimrc..."
vimrcFile="$HOME/.vimrc"
cat > "$vimrcFile" << EOF
" Use system clipboard (https://stackoverflow.com/questions/27898407/intellij-idea-with-ideavim-cannot-copy-text-from-another-source):
set clipboard=unnamedplus

" Enable repeatable pasting in visual mode (https://stackoverflow.com/questions/7163947/paste-multiple-times):
xnoremap p pgvy

" Wrap lines:
set wrap
EOF

echo "4. Installing NeoVim..."
# 1. Do not install via snap, because it might cause problems like this:
#    https://github.com/LunarVim/LunarVim/issues/3612#issuecomment-1441131186
# 2. Do not install via apt, because it has an old version
brew install neovim

echo "5. Installing LazyVim..."
# LazyVim: https://www.lazyvim.org/
mkdir -p "$HOME/.config/nvim"
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

echo "6. Setting light LazyVim theme..."
# Theme: https://github.com/folke/tokyonight.nvim
nvimColorConfigFile="$HOME/.config/nvim/lua/plugins/colorscheme.lua"
touch "$nvimColorConfigFile"
cat > "$nvimColorConfigFile" << EOF
return {
	{
	  "folke/tokyonight.nvim",
	  lazy = true,
	  opts = { style = "day" },
	}
}
EOF

echo "7. Opening an nvim application in order to initialize it..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    gnome-terminal -- bash -c "nvim test.lua -c 'startinsert'" # Need lua file to initiate LSP
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
# On Apple Script:
#   1. https://apple.stackexchange.com/a/335779
#   2. https://stackoverflow.com/questions/56862644/open-iterm2-from-bash-script-run-commands#comment105229692_56862822
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
  else
    echo "Unexpected error occurred. The requested action wasn't preformed correctly"
    exit 1
fi
echo "Once an nvim application is initialized, close it and press Enter to continue..."
read voidInput

echo "8. Fixing JSON LSP bug..."
# At the moment there is a bug related to JSON LSP installation within NeoVim
# It is reproducible at least on macOS. Therefore, JSON LSP is being disabled below:
masonConfigFile="$HOME/.local/share/nvim/lazy/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/server.lua"
sed -i.backup 's/\["jsonls"\] = "json-lsp",//g' "$masonConfigFile"
trash-put "${masonConfigFile}.backup"

echo "9. Disabling plugin updates notifications..."
lazyVimBasicConfigFile="$HOME/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/config.lua"
sed -i.backup 's/notify = true, -- get a notification when new updates/notify = false, -- get a notification when new updates/g' "$lazyVimBasicConfigFile"
trash-put "${lazyVimBasicConfigFile}.backup"

echo "10. Disabling autoformat on save..."
lazyVimInitFile="$HOME/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/lsp/init.lua"
sed -i.backup 's/autoformat = true,/autoformat = false,/g' "$lazyVimInitFile"
trash-put "${lazyVimInitFile}.backup"
cat >> "$HOME/.config/nvim/lua/config/autocmds.lua" << EOF

-- Disable autoformat for all file types
vim.api.nvim_create_autocmd({ "FileType" }, {
  callback = function()
    vim.b.autoformat = false
  end,
})
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                11. FONTS                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="fonts"
# DOCUMENTATION:
#   https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono/NoLigatures
#   https://fonts.google.com/noto/specimen/Noto+Serif?query=noto+seri (sic)

informAboutProcedureStart

echo "Installing JetBrains Mono Nerd Font..."
brew install --cask font-jetbrains-mono-nerd-font

echo "Installing Open Sans Font..."
brew install --cask font-open-sans

echo "Installing Noto Serif Font..."
brew install --cask font-noto-serif

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                11. RUST                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="rust"
# DOCUMENTATION:
#   https://www.rust-lang.org/tools/install
#   https://stackoverflow.com/a/57251636 (non-interactive installation)

informAboutProcedureStart

echo "Installing rust..."
cat >> "$shellFile" << EOF

# RUST:
export PATH="\$HOME/.cargo/bin:\$PATH"
EOF
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
sleep 3 # Give the command above some time to be finished
source "$HOME/.cargo/env" # Post-installation command suggested by the script above

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               11. 0_PROG                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="0_prog"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Default directory for code repositories. It is hardcoded in related scripts

informAboutProcedureStart

echo "Creating a default directory for code repositories..."
codeRepoDir="$HOME/0_prog"
if [ -d "$codeRepoDir" ]
 then
   echo "Directory already exists..."
 else
   mkdir -p "$codeRepoDir"
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                12. ALTTAB                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="alttab"
# DOCUMENTATION:
#   https://github.com/lwouis/alt-tab-macos

informAboutProcedureStart

echo "1. Downloading the AltTab application..."
curl -s https://api.github.com/repos/lwouis/alt-tab-macos/releases/latest \
   | grep "browser_download_url.*AltTab-.*\.zip" \
   | cut -d : -f 2,3 \
   | tr -d \" \
   | wget -i -

echo "2. Installing the AltTab application..."
altTabInstallationArchive=$(ls -1 AltTab-*.zip | head -n 1)
altTabTempDir="$(pwd)/AltTabTempDir"
if [ -d "$altTabTempDir" ]
 then
   echo "Detected $altTabTempDir. Removing..."
   trash-put "$altTabTempDir"
fi
mkdir -p "$altTabTempDir"
tar --extract --verbose --file "$altTabInstallationArchive" --directory "$altTabTempDir"
sudo cp -R "$altTabTempDir/AltTab.app" "$HOME/Applications"
sleep 5 # Let the above command to be finished

echo "3. Initiating the AltTab application..."
open -a AltTab
sleep 5 # Give the application time to be initiated

printf "\n4. Give AltTab necessary permissions if requested. Press Enter when done...\n"
read voidInput

echo "5. Killing the AltTab application..."
killall AltTab
sleep 3 # Give the application time to be killed

echo "6. Configuring the AltTab application..."
# Disable menu bar icon:
defaults write com.lwouis.alt-tab-macos.plist menubarIcon -int 3
defaults write com.lwouis.alt-tab-macos.plist holdShortcut -string "⌘"

echo "7. Making the AltTab application to ignore iTerm2 when no iTerm2 windows are open..."
finalBlackList="[{\"ignore\":\"0\",\"bundleIdentifier\":\"com.McAfee.McAfeeSafariHost\",\"hide\":\"1\"},{\"ignore\":\"0\",\"bundleIdentifier\":\"com.apple.finder\",\"hide\":\"2\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.microsoft.rdc.macos\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.teamviewer.TeamViewer\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"org.virtualbox.app.VirtualBoxVM\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.parallels.\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.citrix.XenAppViewer\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.citrix.receiver.icaviewer.mac\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.nicesoftware.dcvviewer\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.vmware.fusion\",\"hide\":\"0\"},{\"ignore\":\"2\",\"bundleIdentifier\":\"com.apple.ScreenSharing\",\"hide\":\"0\"},{\"ignore\":\"0\",\"bundleIdentifier\":\"com.googlecode.iterm2\",\"hide\":\"2\"}]"
defaults write com.lwouis.alt-tab-macos.plist blacklist -string "$finalBlackList"

echo "8. Opening the AltTab application..."
open -a AltTab

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                 13. TILES                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="tiles"
# DOCUMENTATION:
#   https://www.sempliva.com/tiles/

informAboutProcedureStart

echo "1. Installing the Tiles application..."
wget https://updates.sempliva.com/tiles/Tiles-latest.dmg
sudo hdiutil attach Tiles-latest.dmg
sudo cp -R /Volumes/Tiles/Tiles.app "$HOME/Applications"
sudo hdiutil unmount /Volumes/Tiles
sleep 4 # let the app to be initialized

echo "2. Configuring the Tiles application..."
# There are certain bugs when configuring this application with `defaults write`
# command, therefore the whole .plist file is transferred:
cp -v "$resourcesDir/mac/defaults/HOME/Library/Preferences/com.sempliva.Tiles.plist" "$HOME/Library/Preferences/com.sempliva.Tiles.plist"

echo "3. Opening the Tiles application..."
open -a Tiles

echo "4. Setting up the Tiles to launch on startup..."
tilesPath="$HOME/Applications/Tiles.app"
# On login item adding: https://apple.stackexchange.com/a/310502
# On variables in the command below: https://stackoverflow.com/q/23923017
# The command below outputs 'login item UNKNOWN', which is ok: https://copyprogramming.com/howto/can-login-items-be-added-via-the-command-line-in-high-sierra?utm_content=cmp-true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$tilesPath"'", hidden:false}' > /dev/null

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             14. GITHUB CLI                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="github cli"
# DOCUMENTATION:
#   https://github.com/cli/cli?tab=readme-ov-file#installation
#   Caching credentials for GitHub CLI: https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git
# NOTES:
#   As of writing this script, the official method of GitHub CLI installation on Linux
#   didn't work (see the issue: https://github.com/cli/cli/issues/6175). For that
#   reason for Linux the program is installed below directly from official binaries.

informAboutProcedureStart

if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    echo "1.1. Downloading GitHub CLI..."
    curl -s https://api.github.com/repos/cli/cli/releases/latest \
      | grep "browser_download_url.*gh.*amd64.deb" \
      | cut -d : -f 2,3 \
      | tr -d \" \
      | wget -i -

    echo "1.2. Installing GitHub CLI..."
    ghCLIIntstallationFile=$(ls -1 gh*amd64.deb | head -n 1)
    sudo dpkg -i "$ghCLIIntstallationFile"
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      echo "1. Installing GitHub CLI..."
      brew install gh
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi

printf "\n2. Caching credentials for GitHub CLI...\n"
echo "   Please perform manual login according to prompts in the terminal."
echo "   If prompted for your preferred protocol for Git operations, select HTTPS."
gh auth login # Two options will be prompted: GitHub + GitHub Enterprise. The first one should be selected.
# <--- here manual login should be performed --->

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            15. SYSTEM SETTINGS                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="system settings"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Closing open System Preferences panes in order to prevent them from overriding settings that will be changed now..."
osascript -e 'tell application "System Preferences" to quit'

echo "Changing Network..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

echo "Changing General - Language & Region..."
defaults write "Apple Global Domain" AppleICUDateFormatStrings '
{
 1 = "y-MM-dd";
}'
defaults write "Apple Global Domain" AppleICUNumberSymbols '
{
 0 = ",";
 1 = ".";
 10 = ",";
 17 = ".";
}'

echo "Changing Accessibility - Display..."
defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -int 1
# Ideally, also the following command should be executed, because without that property
# the "Reduce transparency" setting might not fully work. However, execution of that command
# within the script fails, but regardless of that failure the setting works as expected after
# the reboot: `defaults write com.apple.universalaccess reduceTransparency -int 1`

echo "Changing Appearance..."
defaults write "Apple Global Domain" AppleAquaColorVariant -int 6
defaults write "Apple Global Domain" AppleHighlightColor -string "0.847059 0.847059 0.862745 Graphite"
defaults write "Apple Global Domain" AppleAccentColor -string "-1"
defaults write "Apple Global Domain" AppleShowScrollBars Always

echo "Changing Control Center..."
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -int 1
defaults write com.apple.airplay showInMenuBarIfPresent -int 0
defaults delete com.apple.Spotlight "NSStatusItem Visible Item-0"

echo "Changing Desktop & Dock..."
defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock mineffect scale
defaults write com.apple.dock "show-process-indicators" -int 0
defaults write com.apple.dock "show-recents" -int 0
defaults write com.apple.dock "mru-spaces" -int 0
defaults write com.apple.dock "wvous-br-corner" -int 1
defaults write com.apple.dock "wvous-br-modifier" -int 0
defaults write com.apple.WindowManager AutoHide -int 1
# Docs: https://apple.stackexchange.com/a/82084
defaults write com.apple.dock autohide-delay -float 1000; killall Dock

echo "Changing Spotlight..."
defaults write com.apple.Spotlight orderedItems -array \
    '{"enabled"=1; "name"="APPLICATIONS";}' \
    '{"enabled"=0; "name"="MENU_EXPRESSION";}' \
    '{"enabled"=0; "name"="CONTACT";}' \
    '{"enabled"=0; "name"="MENU_CONVERSION";}' \
    '{"enabled"=0; "name"="MENU_DEFINITION";}' \
    '{"enabled"=0; "name"="DOCUMENTS";}' \
    '{"enabled"=0; "name"="EVENT_TODO";}' \
    '{"enabled"=0; "name"="DIRECTORIES";}' \
    '{"enabled"=0; "name"="FONTS";}' \
    '{"enabled"=0; "name"="IMAGES";}' \
    '{"enabled"=0; "name"="MESSAGES";}' \
    '{"enabled"=0; "name"="MOVIES";}' \
    '{"enabled"=0; "name"="MUSIC";}' \
    '{"enabled"=0; "name"="MENU_OTHER";}' \
    '{"enabled"=0; "name"="PDF";}' \
    '{"enabled"=0; "name"="PRESENTATIONS";}' \
    '{"enabled"=0; "name"="MENU_SPOTLIGHT_SUGGESTIONS";}' \
    '{"enabled"=0; "name"="SPREADSHEETS";}' \
    '{"enabled"=0; "name"="SYSTEM_PREFS";}' \
    '{"enabled"=0; "name"="TIPS";}' \
    '{"enabled"=0; "name"="BOOKMARKS";}'

echo "Changing Sound..."
sudo nvram StartupMute=%01

echo "Changing Lock Screen..."
defaults -currentHost write com.apple.screensaver idleTime 0
sudo pmset -b displaysleep 10
sudo pmset -c displaysleep 20

echo "Changing Keyboard..."
defaults write -g com.apple.keyboard.fnState -bool true
defaults write com.apple.HIToolbox AppleFnUsageType -int 0
defaults write "Apple Global Domain" InitialKeyRepeat -int 15
defaults write "Apple Global Domain" KeyRepeat -int 2
defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled 0
echo "Go to 'System Preferences' -> 'Keyboard' and set preferrable input sources"
echo "Press Enter to continue..."
read voidInput

echo "Changing Trackpad..."
defaults write "Apple Global Domain" "com.apple.trackpad.forceClick" -int 0
defaults write "Apple Global Domain" "com.apple.trackpad.scaling" -string "1.5"
defaults write "com.apple.AppleMultitouchTrackpad" Clicking -int 1
defaults write "com.apple.driver.AppleBluetoothMultitouch.trackpad" Clicking -int 1

echo "Miscellaneous changes..."
# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
# Clean Dock
defaults delete com.apple.dock persistent-apps
defaults delete com.apple.dock persistent-others
defaults delete com.apple.dock recent-apps
killall Dock
# Disable desktop icons
defaults write com.apple.finder CreateDesktop false
killall Finder

echo ""
echo "Setting Touch ID..."
echo "Go to 'System Preferences' -> 'Touch ID & Password' and set your Touch ID"
echo "Press Enter to continue..."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                 16. DOCKER                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="docker"
# DOCUMENTATION:
#   https://docs.docker.com/desktop/
# NOTES:
#   1. Docker cannot work natively on Mac and requires a VM for that.
#   2. There is no straightforward and official way to install on Mac Docker that can
#      be managed exclusively via terminal - the official way is to use Docker Desktop.
#      For a terminal solution a workaround is required.
#   3. Docker Desktop requires a paid license for bigger organizations.
#   4. `podman` was tested as Docker replacement, but it doesn't work well with Docker Compose files.
#   5. Docker with `minikube` was tested, but it brings a lot of bloatware related to Kubernetes
#      (https://dhwaneetbhatt.com/blog/run-docker-without-docker-desktop-on-macos)

informAboutProcedureStart

zsh < "$resourcesDir/mac/install_docker_on_mac.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               17. WALLPAPER                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="wallpaper"
# DOCUMENTATION:
#   https://apple.stackexchange.com/a/348454
# NOTES:
#   Wallpaper RGB: 82,94,84

informAboutProcedureStart

echo "1. Setting up variables..."
wallpaperFileName="background.png"
wallpaperDestinationDir="$HOME/Pictures"
wallpaperDestinationPath="$wallpaperDestinationDir/$wallpaperFileName"

echo "2. Cleaning the path for the wallpaper..."
if [ -f "$wallpaperDestinationPath" ]
 then
   trash-put "$wallpaperDestinationPath"
fi

echo "3. Copying the wallpaper to the destination directory..."
wallpaperResourcesPath="$resourcesDir/$wallpaperFileName"
cp -rf "$wallpaperResourcesPath" "$wallpaperDestinationDir"

echo "4. Setting up the wallpaper..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    dconf write /org/gnome/desktop/background/picture-uri "'$wallpaperDestinationPath'"
    dconf write /org/gnome/desktop/screensaver/picture-uri "'$wallpaperDestinationPath'"
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      osascript -e 'tell application "System Events" to tell every desktop to set picture to "'"$wallpaperDestinationPath"'"'
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           18. MICROSOFT EDGE                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="microsoft edge"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Automation of browser settings isn't reasonable because of dynamic nature of the application.
#   Attempts for such automation were made, but the solution wasn't sustainable and reproducible
#   to the satisfying extent

informAboutProcedureStart

echo "Installing Microsoft Edge..."
brew install --cask microsoft-edge

echo "Microsoft Edge will be opened now..."
open -a "Microsoft Edge"

echo "Sign in with your Microsoft Edge account and sync the settings"
echo "Press Enter to continue"
read voidInput

echo "Perform manually unsynchronized settings:"
echo "-> Privacy, search, and services"
echo "---> Services"
echo "-----> Address bar and search"
echo "-------> Search engine used in the address bar: [Google]"
echo "-> Appearance:"
echo "---> Customize toolbar:"
echo "-----> Show profile type in the profile button: [disable]"
echo "-----> Show Workspaces: [disable]"
echo "-> Sidebar:"
echo "---> App and notification settings"
echo "-----> Copilot: [disable all]"
echo "-> Default browser"
echo "---> [Make default]"
echo "-> Downloads"
echo "--> Location: [$HOME/Desktop]"

echo "Press Enter to continue"
read voidInput

echo "Closing Microsoft Edge..."
killAll "Microsoft Edge"

echo "Setting Edge as the default browser..."
brew install defaultbrowser
sleep 3 # Give some time to finish installation
defaultbrowser edgemac

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           19. DISPLAY BRIGHTNESS                            #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="display brightness"
# DOCUMENTATION:
#   n/a
# NOTES:
#   There is no straightforward way how to programmatically disable automatic brightness
#   adjustments setting. Several solutions were tried (e.g. https://stackoverflow.com/a/41915690),
#   but none of them worked well.

informAboutProcedureStart

echo "1. Setting max screen brightness..."
# Docs: https://www.maketecheasier.com/adjust-screen-brightness-from-terminal-macos/
while true; do
	osascript -e 'tell application "System Events"' -e 'key code 144' -e ' end tell'
	if [[ $? -eq 0 ]]; then
		break
	fi
 echo "Unable to execute the script. Provide the permissions required for the running application in System Preferences -> Privacy Tab -> Accessibility"
	sleep 5
done
counter=1
while [ $counter -le 20 ]
 do
   osascript -e 'tell application "System Events"' -e 'key code 144' -e ' end tell'
   ((counter++))
done

printf "\n2. Disabling automatic brightness adjustments...\n"
echo "Go to 'System Preferences' -> 'Displays':"
echo "   Uncheck the checkbox 'Automatically adjust brightness'"
echo "Press Enter to continue..."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         20. FERNFLOWER (DECOMPILER)                         #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="fernflower (decompiler)"
# DOCUMENTATION:
#   https://github.com/fesh0r/fernflower
# NOTES:
#   1. CFR (https://github.com/leibnitz27/cfr) decompiler was also tested, but it
#      extracted only Java files, discarding META-INF, resources etc.
#   2. The installation is performed via mounting a `fernflower.jar` file stored in
#      the Linux Mantra repository. That file is a custom build from the source code
#      (https://github.com/fesh0r/fernflower) based on the
#      2080f165fa49bcc744a7b6185a8ec64c4cf52c4c commit from 2022-09-23 (14:05, +0200).
#      However, due to specific issues, before the build one change in the source code
#      was made. Within that change three following lines from the `StructContext.java`
#      file were commented out:
#      142   if (!testPath.normalize().startsWith(file.toPath().normalize())) { // check for zip slip exploit
#      143     throw new RuntimeException("Zip entry '" + entry.getName() + "' tries to escape target directory");
#      144   }

informAboutProcedureStart

fernflowerInstallDir="$HOME/.local/share/java/fernflower"
fernflowerJarSourceAbs="$resourcesDir/fernflower/fernflower.jar"

if [ -d "$fernflowerInstallDir" ] || [ -f "$fernflowerInstallDir" ]
 then
   echo "Installation path is occupied. Removing in order to recreate: $fernflowerInstallDir..."
   sudo trash-put "$fernflowerInstallDir"
fi

echo "Creating an installation directory: $fernflowerInstallDir..."
mkdir -p "$fernflowerInstallDir"

echo "Mounting a fernflower jar..."
# Note that the path to the target file
# ($HOME/.local/share/java/fernflower/fernflower.jar) is hardcoded in xplr:
cp "$fernflowerJarSourceAbs" "$fernflowerInstallDir"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           21. XPLR (FILE EXPLORER)                          #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="xplr (file explorer)"
# DOCUMENTATION:
#   https://github.com/sayanarijit/xplr
# NOTES:
#   There was an attempt to add to xplr functionality of showing the number of
#   items in directories, but it caused performance issues.

informAboutProcedureStart

echo "1. Removing previous settings and application if present..."
brew uninstall xplr
sudo rm -f /usr/bin/xplr
sudo rm -f /usr/local/bin/xplr
xplrSettingsDir="$HOME/.config/xplr"
if [ -d "$xplrSettingsDir" ]
 then
   echo "Detected $xplrSettingsDir. Removing..."
   trash-put "$xplrSettingsDir"
fi

echo "2. Installing xplr..." # docs: https://xplr.dev/en/install
# Hardcoded version is installed, because new versions of xplr
# are very dynamic, UI constantly changes, and old settings stop
# working correctly:
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    wget https://github.com/sayanarijit/xplr/releases/download/v0.20.2/xplr-linux.tar.gz
    tar --verbose --extract --file xplr-linux.tar.gz
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      wget https://github.com/sayanarijit/xplr/releases/download/v0.20.2/xplr-macos.tar.gz
      tar --verbose --extract --file xplr-macos.tar.gz
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi
# On binary installation: https://superuser.com/a/7163
sudo cp ./xplr /usr/local/bin
mkdir -p "$xplrSettingsDir"

echo "3. Composing a main configuration file..."
mainConfigurationFile="$resourcesDir/xplr/HOME/.config/xplr/init.lua"

echo "3.1. Extracting an xplr version..." # docs: https://xplr.dev/en/post-install
xplrVersion=$(xplr --version | cut -d ' ' -f 2) # result like: 0.19.0
xplrVersionAsConfigEntry="version = \"${xplrVersion:?}\"" # result like: version = "0.19.0"
echo "-- 1_version" > "$resourcesDir/xplr/HOME/.config/xplr/1_version.lua"
echo "$xplrVersionAsConfigEntry" >> "$resourcesDir/xplr/HOME/.config/xplr/1_version.lua"
cat "$resourcesDir/xplr/HOME/.config/xplr/1_version.lua" > "$mainConfigurationFile"

echo "3.2. Setting up plugins..." # docs: https://xplr.dev/en/installing-plugins + docs for every plugin

echo "3.2.1. Creating plugin settings..."
echo "" >> "$mainConfigurationFile"
cat "$resourcesDir/xplr/HOME/.config/xplr/2_plugin_config.lua" >> "$mainConfigurationFile"

echo "3.2.2. Installing plugins..."
targetPluginsDir="$HOME/.config/xplr/plugins"
mkdir -p "$targetPluginsDir"
cp -rf "$resourcesDir/xplr/HOME/.config/xplr/plugins/command-mode" "$targetPluginsDir"
cp -rf "$resourcesDir/xplr/HOME/.config/xplr/plugins/icons" "$targetPluginsDir"
cp -rf "$resourcesDir/xplr/HOME/.config/xplr/plugins/trash-cli" "$targetPluginsDir"

echo "3.2.3. Configuring 'command-mode' plugin..."
echo "" >> "$mainConfigurationFile"
cat "$resourcesDir/xplr/HOME/.config/xplr/3_custom_commands-$osType.lua" >> "$mainConfigurationFile"

echo "3.3. Applying general configurations..."
echo "" >> "$mainConfigurationFile"
cat "$resourcesDir/xplr/HOME/.config/xplr/4_general_config.lua" >> "$mainConfigurationFile"

echo "3.4. Fixing 'create file' bug if this is macOS..."
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
 then
   cat "$resourcesDir/xplr/HOME/.config/xplr/5_create_file_bugfix.lua" >> "$mainConfigurationFile"
fi

echo "4. Copying the composed main configuration file to its destination"
cp -f "$mainConfigurationFile" "$HOME/.config/xplr"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                  22. HOME DEFAULT DIRECTORIES CLEANING                      #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="home default directories cleaning"
# DOCUMENTATION:
#   n/a
# NOTES:
#   $HOME contains a number of default directories. Some of them are
#   useless and can be removed (Documents, Movies, Music, Public).

informAboutProcedureStart

sudo rm -rf "$HOME/Documents"
sudo rm -rf "$HOME/Public"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              23. REPO (AEM)                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="repo (aem)"
# DOCUMENTATION:
#   https://github.com/Adobe-Marketing-Cloud/tools/tree/master/repo

informAboutProcedureStart

echo "Installing a repo tool..."
brew tap adobe-marketing-cloud/brews
brew install adobe-marketing-cloud/brews/repo

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             24. INTELLIJ IDEA                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="intellij idea"
# DOCUMENTATION:
#   n/a
# NOTES:
#   n/a

informAboutProcedureStart

echo "1. Setting up variables..."
projectName="demoproject"
tempProjectDir="$tempDir/$projectName"
ideavimrcFile="$HOME/.ideavimrc"
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    jetbrainsConfigDir="$HOME/.config/JetBrains"
    launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      jetbrainsConfigDir="$HOME/Library/Application Support/JetBrains"
      launcherPath="/opt/homebrew/bin/idea"
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi

printf "\n2. Purging IntelliJ IDEA if present...\n"
pids=$(pgrep -f idea)
if [ -n "$pids" ]; then
    kill $pids
fi
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    sudo snap remove intellij-idea-ultimate
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      brew uninstall intellij-idea
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi
trash-put "$jetbrainsConfigDir"
trash-put "$ideavimrcFile"
trash-put "$HOME/.cache/JetBrains"
trash-put "$HOME/.local/share/JetBrains"

printf "\n3. Installing IntelliJ IDEA...\n"
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    sudo snap install intellij-idea-ultimate --classic
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      brew install intellij-idea
  else
    echo "Unexpected error occurred. Update failed"
    exit 1
fi

printf "\n4. A temporary project will be set up and IntelliJ IDEA will be opened...\n"
if [ -d "$tempProjectDir" ]
  then
    echo "Old temporary project directory found. Removing..."
    trash-put "$tempProjectDir"
fi
yes | mvn archetype:generate                          \
  -DarchetypeGroupId=org.apache.maven.archetypes      \
  -DarchetypeArtifactId=maven-archetype-quickstart    \
  -DarchetypeVersion=1.4                              \
  -DgroupId=demo.groupId                              \
  -DartifactId="$projectName"                         \
  -Dversion=1.0-SNAPSHOT
echo "Starting IntelliJ IDEA..."
nohup "$launcherPath" nosplash "$tempProjectDir" > /dev/null 2>&1 &

echo ""
echo "5. Perform initial settings..."
echo "   5.1. Choose 'Do not import settings' if asked."
echo "   5.2. Accept user agreement if requested."
echo "   5.3. Choose 'Don't Send' for data sharing request."
echo "   5.4. Activate IntelliJ IDEA if asked."
echo "   5.5. Choose to trust projects in a temporary directory if asked."
echo "Press Enter to continue..."
read voidInput

echo "6. Perform synchronizable settings:"
echo "   Toolbar -> File -> Manage IDE Settings -> Backup and Sync -> "
echo "   -> Enable Backup and Sync"
echo "   -> Get settings from Account"
echo "Wait until settings are synchronized. After the synchronization is finished, press Enter to continue..."
read voidInput
echo "Shutting down IntelliJ IDEA..."
pids=$(pgrep -f idea)
if [ -n "$pids" ]; then
    kill $pids
fi

echo "Starting IntelliJ IDEA..."
nohup "$launcherPath" nosplash "$tempProjectDir" > /dev/null 2>&1 &

echo ""
echo "7. Perform non-synchronizable Git settings:"
echo "   Toolbar -> File -> New Projects Setup -> Settings for New Projects"
echo "   -> Version Control"
echo "      -> Confirmation"
echo "         -> When files are created: Do not add"
echo "         -> When files are deleted: Do not remove"
echo "Press Enter to continue..."
read voidInput

echo "8. Perform non-synchronizable Checkstyle settings:"
echo "   Toolbar -> File -> New Projects Setup -> Settings for New Projects"
echo "   -> Tools"
echo "      -> Checkstyle"
echo "         -> Add and apply a custom rule set at this link: https://raw.githubusercontent.com/ciechanowiec/linux_mantra/master/resources/static_code_analysis/checkstyle.xml"
echo "Press Enter to continue..."
read voidInput

echo "9. Perform non-synchronizable Maven settings:"
echo "   Toolbar -> File -> New Projects Setup -> Settings for New Projects"
echo "   -> Build, Execution, Deployment"
echo "   -> Build Tools"
echo "   -> Maven"
echo "   -> Importing"
echo "      -> Check Automatically download 'Sources', 'Documentation', 'Annotations'"
echo "Press Enter to continue..."
read voidInput

echo "10. Perform non-synchronizable shell check settings."
echo "   -> Open in IntelliJ any Bash script with .sh extension."
echo "   -> Click 'Install' in the pop-up window above about shell check plugin."
echo "Press Enter to continue..."
read voidInput

echo "11. Setting up file templates (removing 'public' modifiers for java files)..."
for IDESubDir in "$jetbrainsConfigDir"/*; do
  if [ -d "$IDESubDir" ]
    then
      dirForFileTemplates="$IDESubDir/fileTemplates/internal"
      if [ -d "$dirForFileTemplates" ]
        then
          echo "Old directory for file templates detected. Removing..."
          trash-put "$dirForFileTemplates"
      fi

      mkdir -p "$dirForFileTemplates"

      annotationFile="$dirForFileTemplates/AnnotationType.java"
      classFile="$dirForFileTemplates/Class.java"
      enumFile="$dirForFileTemplates/Enum.java"
      interfaceFile="$dirForFileTemplates/Interface.java"
      recordFile="$dirForFileTemplates/Record.java"

      touch "$annotationFile"
      touch "$classFile"
      touch "$enumFile"
      touch "$interfaceFile"
      touch "$recordFile"

cat > "$annotationFile" << EOF
#if (\${PACKAGE_NAME} && \${PACKAGE_NAME} != "")package \${PACKAGE_NAME};#end
#parse("File Header.java")
@interface \${NAME} {
}
EOF

cat > "$classFile" << EOF
#if (\${PACKAGE_NAME} && \${PACKAGE_NAME} != "")package \${PACKAGE_NAME};#end
#parse("File Header.java")
class \${NAME} {
}
EOF

cat > "$enumFile" << EOF
#if (\${PACKAGE_NAME} && \${PACKAGE_NAME} != "")package \${PACKAGE_NAME};#end
#parse("File Header.java")
enum \${NAME} {
}
EOF

cat > "$interfaceFile" << EOF
#if (\${PACKAGE_NAME} && \${PACKAGE_NAME} != "")package \${PACKAGE_NAME};#end
#parse("File Header.java")
interface \${NAME} {
}
EOF

cat > "$recordFile" << EOF
#if (\${PACKAGE_NAME} && \${PACKAGE_NAME} != "")package \${PACKAGE_NAME};#end
#parse("File Header.java")
record \${NAME}() {
}
EOF

  fi
done

echo "12. Setting up .ideavimrc file..."
touch "$ideavimrcFile"
cat > "$ideavimrcFile" << EOF
source ~/.vimrc

" Make by default search case insensitive (https://stackoverflow.com/questions/2287440/how-to-do-case-insensitive-search-in-vim):
set ignorecase

" Disable error bells (https://stackoverflow.com/questions/11489428/how-to-make-vim-paste-from-and-copy-to-systems-clipboard):
set visualbell
set noerrorbells

" Highlight search results and clear highlighting on escape in normal mode:
set hls
nnoremap <ESC> :noh<CR>

" Fix this behaviour: after ESC to close the popup menu, the cursor moves left instead of staying in the space place
map <C-F10> <Action>(ShowPopupMenu)<Right>
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                25. PAINT X                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="paint x"
# DOCUMENTATION:
#   https://paint-x.com/

informAboutProcedureStart

echo "1. Installing the Paint X application..."
wget https://cdn.paint-x.com/cdnpaintx/dist/PaintX-6.0.dmg
sudo hdiutil attach PaintX-6.0.dmg
sudo cp -v -R "/Volumes/Paint X/Paint X.app" "$HOME/Applications"
sudo hdiutil unmount "/Volumes/Paint X"

echo "2. Open the Paint X application and activate it"
echo "   Press Enter to continue..."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            26. PROFILE IMAGE                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="profile image"
# DOCUMENTATION:
#   https://apple.stackexchange.com/a/432510

informAboutProcedureStart

echo "Setting up a profile image..."
photoSourcePath="$resourcesDir/avatar.jpg"
dscl . delete "$HOME" JPEGPhoto
dscl . delete "$HOME" Picture
tmp="$(mktemp)"
printf "0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto\n%s:%s" "$(whoami)" "$photoSourcePath" > "$tmp"
dsimport "$tmp" /Local/Default M
rm "$tmp"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           27. COMMON REPOS                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="common repos"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Cloning own repos..."
cd "$HOME/0_prog" || { echo "Failed to navigate to $HOME/0_prog. Exiting."; exit 1; }
gh repo clone dock_aem
gh repo clone linux_mantra

echo "Cloning and resolving Apache Jackrabbit Oak repository..."
oakDir="$HOME/0_prog/jackrabbit-oak"
mkdir -v -p "$oakDir"
if [ ! -d "$oakDir/.git" ]; then
    echo "Cloning an Oak repository..."
    git clone https://github.com/apache/jackrabbit-oak.git "$oakDir"
else
    echo "Oak repository already exists. Skipping cloning."
fi
cd "$oakDir" || { echo "Failed to navigate to $oakDir. Exiting."; exit 1; }
mvn --fail-never dependency:sources && mvn --fail-never dependency:sources dependency:resolve -Dclassifier=javadoc

echo "Cloning Apache Felix repository..."
felixDir="$HOME/0_prog/felix-dev"
mkdir -v -p "$felixDir"
if [ ! -d "$felixDir/.git" ]; then
    echo "Cloning a Felix repository..."
    git clone https://github.com/apache/felix-dev.git "$felixDir"
else
    echo "Felix repository already exists. Skipping cloning."
fi

echo "Cloning Apache Sling repositories..."
apacheSlingAllReposDir="$HOME/0_prog/apache_sling"
aggregatorDir="$apacheSlingAllReposDir/sling-aggregator"
mkdir -v -p "$apacheSlingAllReposDir"
mkdir -v -p "$aggregatorDir"
if [ ! -d "$aggregatorDir/.git" ]; then
    echo "Cloning Apache Sling Aggregator repository..."
    git clone https://github.com/apache/sling-aggregator.git "$aggregatorDir"
else
    echo "Apache Sling Aggregator repository already exists. Skipping cloning."
fi
cd "$aggregatorDir" || { echo "Failed to navigate to $aggregatorDir. Exiting."; exit 1; }
chmod +x generate-repo-list.sh
repo_list=$(./generate-repo-list.sh)
IFS=$'\n' read -r -d '' -a repos <<< "$repo_list"
total_repos=${#repos[@]}
cloned_repos=0
for repo in "${repos[@]}"; do
    # Skip empty lines or invalid URLs
    if [[ -z "$repo" || "$repo" != http*://* ]]; then
        continue
    fi
    repo_name=$(basename -s .git "$repo")
    if [ ! -d "$apacheSlingAllReposDir/$repo_name" ]; then
        echo "Cloning $repo into $apacheSlingAllReposDir/$repo_name..."
        git clone "$repo" "$apacheSlingAllReposDir/$repo_name"
        if [ $? -eq 0 ]; then
            cloned_repos=$((cloned_repos + 1))
        else
            echo "Failed to clone $repo. Skipping."
        fi
    else
        echo "Skipping $repo_name (directory exists)."
    fi
    echo "Cloned $cloned_repos out of $total_repos repositories."
    if [ "$cloned_repos" -ge 400 ]; then
        echo "Cloned 400 repositories. Stopping further cloning."
        break
    fi
done

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              20. CLEANUP                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="cleanup"
# DOCUMENTATION:
#   n/a
informAboutProcedureStart
echo "1. Going back to the initial working directory: $initialWorkingDirectory..."
cd "$initialWorkingDirectory" || exit 1
echo "2. Removing the temporary directory..."
trash-put "$tempDir"
informAboutProcedureEnd

echo ""
echo "Reboot for all changes to come into force."
