#!/bin/bash

procedureId="null"

###############################################################################
#                                                                             #
#                                                                             #
#                             COMMON FUNCTIONS                                #
#                                                                             #
#                                                                             #
###############################################################################
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

echo "4. Downloading packages information from all configured sources..."
sudo apt update -y

echo "5. Installing available upgrades of all packages currently installed on the system..."
sudo apt upgrade -y

echo "6. Removing unnecessary dependencies..."
sudo apt autoremove -y

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              2. BASIC UTILS                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="basic utils"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Installing curl (transfer a URL)..."
# Don’t install curl via snap - it might work incorrectly then
sudo apt install curl -y

echo "Installing tree (list contents of directories in a tree-like format)..."
sudo apt install tree -y

echo "Installing unzip (file decompressor)..."
sudo apt install unzip -y

echo "Installing p7zip (file decompressor)..."
sudo apt install p7zip-full -y

echo "Installing wget (non-interactive network downloader)..."
sudo apt install wget -y

echo "Installing postman (app for building and using APIs)..."
sudo snap install postman

echo "Installing teams (business communication platform)..."
sudo snap install teams

echo "Installing usb-creator-gtk (startup disk creator)..."
sudo apt install usb-creator-gtk -y

echo "Installing vim (terminal-based text editor)..."
sudo apt install vim -y

echo "Installing pip (tool for installing and managing Python packages)..."
sudo apt install python3-pip -y

echo "Installing htop (interactive process viewer)..."
sudo apt install htop

echo "Installing atril (.djvu files viewer)..."
sudo apt install atril -y

echo "Installing mpv (media player)..."
sudo apt install mpv -y

echo "Installing audacious (audio player)..."
sudo apt install audacious -y

echo "Installing simplescreenrecorder (screencast program)..."
sudo apt install simplescreenrecorder -y

echo "Installing rtorrent (terminal-based BitTorrent client)..."
sudo apt install rtorrent -y

echo "Installing vidcutter (video cutter)..."
# DOCUMENTATION: https://github.com/ozmartian/vidcutter
sudo snap install vidcutter

echo "Installing ffmpeg (audio/video converter)..."
sudo apt install ffmpeg -y

echo "Installing traceroute (program for printing the route packets trace to network host)..."
sudo apt install traceroute -y

echo "Installing trash-cli (CLI for removing files)..."
sudo apt install trash-cli -y

echo "Installing breeze (graphical assets required for cursor configuration and 'kolourpaint' package)..."
sudo apt install breeze -y

echo "Installing kolourpaint (graphical editor)..."
sudo apt install kolourpaint -y

echo "Installing kid3 (music tags editor)..."
sudo apt install kid3 -y

echo "Installing yt-dlp (YouTube downloader)..."
# Do not perform installation via other package managers - it might cause problems:
sudo pip install yt-dlp

echo "Installing fzf (file finder)..."
sudo apt install fzf -y

echo "Installing xclip (CLI-based clipboard selections)..."
sudo apt install xclip -y

echo "Installing xdotool (input automations tool)..."
sudo apt install xdotool -y

echo "Installing icdiff (tool for comparing files/directories)..."
sudo apt install icdiff -y

# This tool was delivered with Ubuntu 20, but isn't delivered with Ubuntu 22.
# It is used further in keyboard shortcuts:
echo "Installing gnome-screenshot (tool for taking screenshots)..."
sudo apt install gnome-screenshot -y

echo "Installing jq (CLI JSON processor)..."
sudo apt install jq -y

echo "Installing ruby (interpreted object-oriented scripting language)..."
sudo apt install ruby -y

echo "Installing asciidoctor-pdf (Asciidoctor converter to backend files)..."
sudo gem install asciidoctor-pdf # `gem` comes from ruby, so ruby must be preinstalled

echo "Installing wavemon (Wi-Fi connection monitor)..."
sudo apt install wavemon -y

echo "Installing inkskape (svg editor)..."
sudo apt install inkscape -y

echo "Installing node (server environment)..."
# Installation docs:
#   https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
#   https://github.com/nodejs/snap
#   https://snapcraft.io/node
sudo snap install node --classic

echo "Installing typescript..."
# Installation docs:
#   bad: https://www.typescriptlang.org/download
#   good: https://lindevs.com/install-typescript-on-ubuntu
sudo npm install -g typescript # `npm` comes from node, so node must be preinstalled

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  3. GIT                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="git"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Installing git..."
sudo apt install git -y

echo "2. Setting up a global git committer..."
echo "Enter global git committer name (first name and surname, eg. John Doe):"
read committerName
echo "Enter global git committer email:"
read committerEmail
git config --global user.name "$committerName"
git config --global user.email "$committerEmail"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                 4. VIM                                      #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="vim"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Setting up vim as default editor..."
sudo update-alternatives --set editor /usr/bin/vim.basic

vimrcFile="$HOME/.vimrc"

cat > "$vimrcFile" << EOF
" Use system clipboard (https://stackoverflow.com/questions/27898407/intellij-idea-with-ideavim-cannot-copy-text-from-another-source):
set clipboard=unnamedplus

" Enable repeatable pasting in visual mode (https://stackoverflow.com/questions/7163947/paste-multiple-times):
xnoremap p pgvy
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             5. BASHRC RELATED                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="bashrc related"
# DOCUMENTATION:
#   n/a
# NOTES:
#   This block contains configurations that change the content of `.bashrc` file
#   and therefore were grouped in this place. Note that content appended to the
#   `.bashrc` file by SDKMAN installation should be appended in the last order -
#   otherwise the SDKMAN might not work correctly.

informAboutProcedureStart

bashrcFile="$HOME/.bashrc"

######################################################################
#                         BASIC ADJUSTMENTS                          #
######################################################################
# DOCUMENTATION:
#   n/a

echo "SUB-PROCEDURE: BASIC ADJUSTMENTS"
echo "1. Changing terminal prompt..."
# Replace this line:
#   PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
# with this line:
#   PS1='\e[0m\e[1m\e[32m\w\e[0m\n❯ '
oldPrompt='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
newPrompt='\e[0m\e[1m\e[32m\w\e[0m\n❯ '
# Details on the following escaping: https://stackoverflow.com/questions/29613304/is-it-possible-to-escape-regex-metacharacters-reliably-with-sed/29626460#29626460
escapedOldPrompt=$(sed 's/[^^\\]/[&]/g; s/\^/\\^/g; s/\\/\\\\/g' <<< "$oldPrompt")
escapedNewPrompt=$(sed 's/[&/\]/\\&/g' <<< "$newPrompt")
sed -i "s/$escapedOldPrompt/$escapedNewPrompt/g" "$bashrcFile"

echo "2. Changing terminal tab naming..."
# Replace this line:
#   PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
# with this line:
#   PS1="\[\e]0;\w\a\]$PS1"
oldTabName='\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1'
newTabName='\[\e]0;\w\a\]$PS1'
# Details on the following escaping: https://stackoverflow.com/questions/29613304/is-it-possible-to-escape-regex-metacharacters-reliably-with-sed/29626460#29626460
escapedOldTabName=$(sed 's/[^^\\]/[&]/g; s/\^/\\^/g; s/\\/\\\\/g' <<< "$oldTabName")
escapedNewTabName=$(sed 's/[&/\]/\\&/g' <<< "$newTabName")
sed -i "s/$escapedOldTabName/$escapedNewTabName/g" "$bashrcFile"

echo "3. Making * to include hidden files..."
# Details on the change: https://askubuntu.com/questions/259383/how-can-i-get-mv-or-the-wildcard-to-move-hidden-files
echo "" >> "$bashrcFile" # Empty line
echo "# MAKING * TO INCLUDE HIDDEN FILES:" >> "$bashrcFile"
echo "shopt -s dotglob" >> "$bashrcFile"

echo "4. Copying bash scripts..."
sourceDirWithScripts="$resourcesDir/scripts"
targetDirWithScripts="$HOME/scripts"
if [ -d "$targetDirWithScripts" ]
  then
    echo "Old directory with scripts detected. Removing..."
    trash-put "$targetDirWithScripts"
fi
echo "Transferring files..."
cp -rf "$sourceDirWithScripts" "$targetDirWithScripts"

echo "5. Setting up aliases..."
echo "" >> "$bashrcFile" # Empty line
cat >> "$bashrcFile" << EOF
# ALIASES:
alias aem_init_archetype='~/scripts/aem_init_archetype.sh'
alias aem_reset_instances='~/scripts/aem_reset_instances.sh'
alias aem_start_author='~/scripts/aem_start_author.sh'
alias aem_start_forms='~/scripts/aem_start_forms.sh'
alias aem_start_publish='~/scripts/aem_start_publish.sh'
alias docker_clean='~/scripts/docker_clean.sh'
alias docker_clean_containers='~/scripts/docker_clean_containers.sh'
alias docker_clean_images='~/scripts/docker_clean_images.sh'
alias docker_clean_networks='~/scripts/docker_clean_networks.sh'
alias docker_clean_volumes='~/scripts/docker_clean_volumes.sh'
alias git_clip_cur_branch="git branch | grep '*' | cut -d ' ' -f 2 | xxclip"
alias git_switch_to_com='~/scripts/git_switch_to_com.sh'
alias idea='~/scripts/idea.sh'
alias logout="pkill -KILL -u $(whoami)"
alias mantra_java='~/scripts/mantra_java.sh'
alias mantra_spring='~/scripts/mantra_spring.sh'
alias xxclip="perl -pe 'chomp if eof' | xclip -selection clipboard" # perl is required to drop the last NL character
gedit() {
  fileName="\$1"
  nohup gedit --new-window "\$fileName" &> /dev/null & disown
}
EOF

echo "6. Adding GitHub CLI autocompletion..."
# Docs: https://cli.github.com/manual/gh_completion
echo "" >> "$bashrcFile" # Empty line
echo "# GH CLI AUTOCOMPLETION:" >> "$bashrcFile"
echo "eval \"\$(gh completion -s bash)\"" >> "$bashrcFile"

######################################################################
#                   HOMEBREW (PACKAGE MANAGER)                       #
######################################################################
# DOCUMENTATION:
#   https://www.digitalocean.com/community/tutorials/how-to-install-and-use-homebrew-on-linux
#   https://docs.brew.sh/Homebrew-on-Linux
# NOTES:
# 1. By default, `homebrew`, which is executed via the command `brew`, isn't added permanently to the PATH.
#    For that reason, in order to have it on the PATH and be able to execute the `brew` command,
#    after `homebrew` installation, it should be added to the PATH. Note that ways of doing it described in
#    official documentation and in almost all tutorials doesn't work. In fact, it should be achieved via the
#    commands used below in the script.
# 2. The first command used below in the script for PATH adjustment appends a new line to the bottom of `.bashrc`
#    file. However, if SDKMAN is installed, its specific entries must be located on the last lines of
#    `.bashrc` file. Therefore, if SDKMAN is installed, it should be installed after the installation
#    of `homebrew` (SDKMAN appends new lines to the bottom of `.bashrc` file automatically during installation).

echo "SUB-PROCEDURE: HOMEBREW (PACKAGE MANAGER)"
echo "1. Installing compiler environment..."
sudo apt install build-essential -y

echo "2. Installing homebrew..."
sudo yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "3. Adding 'brew' to PATH..."
# This line effectively adds `brew` to the PATH:
echo "" >> "$bashrcFile" # Empty line
echo "# 'brew' COMMAND:" >> "$bashrcFile"
echo "export PATH=\"\$PATH:/home/linuxbrew/.linuxbrew/bin\"" >> "$bashrcFile"
# However, without these two lines, commands related to `brew` might not work correctly:
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

######################################################################
#                               SDKMAN                               #
######################################################################
# DOCUMENTATION:
#   https://sdkman.io/install
# NOTES:
#   SDKMAN's entries in `.bashrc` file (SDKMAN appends new lines to the bottom of `.bashrc`
#   file automatically during installation) must be located on the last lines of`.bashrc` file.

echo "SUB-PROCEDURE: SDKMAN"
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  6. JAVA                                    #
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
# For some reason, without the following sourcing, sdk command might not be recognized:
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "Installing Java 8..."
yes | sdk install java 8.0.345-tem

echo "Installing Java 11..."
yes | sdk install java 11.0.16-tem

echo "Installing Java 17..."
yes | sdk install java 17.0.4-tem

echo "Setting up Java 11 as the default one..."
sdk default java 11.0.16-tem

echo "Enabling the installed program in the current console..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             6. SPRING BOOT                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="spring boot"
# DOCUMENTATION:
#   n/a
# NOTES:
#   installed mainly for Spring Boot CLI

informAboutProcedureStart

echo "Installing Spring Boot..."
sdk install springboot

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                6. MAVEN                                     #
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
# For some reason, without this sourcing, sdk command might not be recognized:
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "Installing Maven..."
yes | sdk install maven 3.9.1

echo "Enabling the installed program in the current console..."
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              6. FIREWALL                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="firewall"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Enabling firewall..."
sudo ufw enable

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                 7. FONTS                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="fonts"
# DOCUMENTATION:
#   https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono/NoLigatures
#   https://fonts.google.com/noto/specimen/Noto+Serif?query=noto+seri (sic)
#   https://medium.com/source-words/how-to-manually-install-update-and-uninstall-fonts-on-linux-a8d09a3853b0

informAboutProcedureStart

localTargetFontsDir="$HOME/.local/share/fonts"
# Ideally the global directory should not be involved, but without it
# GNOME Terminal might not recognize some patched custom fonts (e.g. Nerd Font):
globalTargetFontsDir="/usr/share/fonts/custom"

echo "1. Creating a temporary directory for new fonts..."
mkdir tempFontsDir

echo "2. Removing all user fonts if installed..."
if [ -d "$localTargetFontsDir" ]
  then
    trash-put "$localTargetFontsDir"
fi
if [ -d "$globalTargetFontsDir" ]
  then
    sudo trash-put "$globalTargetFontsDir"
fi

echo "3. Clearing and regenerating fonts cache..."
fc-cache -f -v

echo "4. Downloading new fonts..."
fontOne="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Regular/complete/JetBrains%20Mono%20NL%20Nerd%20Font%20Complete%20Mono%20Regular.ttf"
fontTwo="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Bold/complete/JetBrains%20Mono%20NL%20Nerd%20Font%20Complete%20Mono%20Bold.ttf"
fontThree="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Italic/complete/JetBrains%20Mono%20NL%20Nerd%20Font%20Complete%20Mono%20Italic.ttf"
fontFour="https://fonts.google.com/download?family=Noto%20Serif"
wget "$fontOne" -P tempFontsDir
wget "$fontTwo" -P tempFontsDir
wget "$fontThree" -P tempFontsDir
wget -O noto_serif.zip "$fontFour"
unzip noto_serif.zip -d noto_serif
cp -rf noto_serif/NotoSerif-Bold.ttf \
  noto_serif/NotoSerif-Italic.ttf \
  noto_serif/NotoSerif-BoldItalic.ttf \
  noto_serif/NotoSerif-Regular.ttf \
  tempFontsDir

echo "5. Creating persistent directories for fonts..."
mkdir -p "$localTargetFontsDir"
sudo mkdir -p "$globalTargetFontsDir"

echo "6. Installing downloaded fonts..."
cp -rf tempFontsDir/* "$localTargetFontsDir"
sudo cp -rf tempFontsDir/* "$globalTargetFontsDir"

echo "7. Installing Open Sans fonts from apt repository..."
sudo apt install -y fonts-open-sans

echo "8. Clearing and regenerating fonts cache..."
fc-cache -f -v

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                7. 0_PROG                                    #
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
#                                  7. DOCKER                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="docker"
# DOCUMENTATION:
#   https://docs.docker.com/desktop/

informAboutProcedureStart

echo "Stopping Docker..."
sudo systemctl stop docker.socket
sudo systemctl stop docker.service

echo "Uninstalling Docker related to Docker Engine..." # Uninstallation as described at https://docs.docker.com/engine/install/ubuntu/
#Older versions of Docker went by the names of docker, docker.io, or docker-engine. Uninstall any such older versions before attempting to install a new version:
sudo apt remove docker docker-engine docker.io containerd runc -y
# Uninstall the Docker Engine, CLI, containerd, and Docker Compose packages:
sudo apt remove docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras -y
# Images, containers, volumes, or custom configuration files on your host aren’t automatically removed. To delete all images, containers, and volumes:
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

echo "Uninstalling Docker related to Docker Desktop..." # Uninstallation as described at https://docs.docker.com/desktop/install/ubuntu/
# Uninstall the tech preview or beta version of Docker Desktop for Linux. Run:
sudo apt remove docker-desktop
# For a complete cleanup, remove configuration and data files at $HOME/.docker/desktop, the symlink at /usr/local/bin/com.docker.cli, and purge the remaining systemd service files:
rm -r $HOME/.docker/desktop
sudo rm /usr/local/bin/com.docker.cli
sudo apt remove docker-desktop -y

echo "Uninstalling Docker related to Docker Compose..." # Uninstallation as described at https://docs.docker.com/compose/install/uninstall/
sudo apt remove docker-compose-plugin -y
rm $DOCKER_CONFIG/cli-plugins/docker-compose
rm /usr/local/lib/docker/cli-plugins/docker-compose

echo "Uninstalling Docker from snap..."
sudo snap remove docker

echo "Setting up the repository..." # As described at https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
sudo apt update -y
sudo apt install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker Engine and Docker Compose..." # As described at https://docs.docker.com/engine/install/ubuntu/ and https://docs.docker.com/compose/install/linux/
sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

echo "Testing Docker installation with sudo..."
sudo docker run hello-world
sudo docker image rm -f hello-world

echo "Setting Docker to be run without 'sudo' prefix..." # As described at https://docs.docker.com/engine/install/linux-postinstall/
sudo groupadd docker
sudo usermod -aG docker "$USER"
# To run Docker without 'sudo' prefix, a reboot after the above commands is required.
# However, it is possible to test without the reboot whether Docker without 'sudo' prefix
# can be run. In order to do that, the 'newgrp docker' command should be executed.
# By default, the 'newgrp docker' command will terminate the script. To prevent it,
# it is needed to use a heredoc code block as shown below, where it is tested
# whether Docker without 'sudo' prefix can be run. However, that 'newgrp docker'
# command has only local effect for one session of the terminal. To run Docker
# without 'sudo' prefix globally, reboot is required, as mentioned above
newgrp docker << EOF
echo "Testing Docker installation without sudo..."
docker run hello-world
docker image rm -f hello-world
EOF

echo "Logging out from Docker Hub..."
docker logout
echo "Logging into Docker Hub..."
echo "Provide your Docker Hub login:"
read -r dockerHubLogin
sudo docker login --username "$dockerHubLogin"
exitCode=$(echo $?)
while [ "$exitCode" -ne 0 ];
  do
    sudo docker login --username "$dockerHubLogin"
    exitCode=$(echo $?)
done

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         7. PULSEAUDIO BUG FIX                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="pulseaudio bug fix"
# DOCUMENTATION:
#   https://askubuntu.com/questions/1232159/ubuntu-20-04-no-sound-out-of-bluetooth-headphones
# NOTES:
#   Fix bluetooth audio issues related to pulseaudio

informAboutProcedureStart

echo "Reinstalling pulseaudio..."
sudo apt install --reinstall pulseaudio pulseaudio-module-bluetooth

echo "Stopping pulseaudio in order to freeze configuration directories..."
systemctl --user stop pulseaudio.socket
systemctl --user stop pulseaudio.service

echo "Removing old pulseaudio configuration directories..."
trash-put "$HOME/.config/pulse"
if [ -d "$HOME/.config/pulse.old" ]
  then
    trash-put "$HOME/.config/pulse.old"
fi

echo "Starting pulseaudio in order to initiate a fresh configuration directory..."
systemctl --user start pulseaudio.socket
systemctl --user start pulseaudio.service

echo "Stopping pulseaudio in order to freeze the fresh configuration directory..."
systemctl --user stop pulseaudio.socket
systemctl --user stop pulseaudio.service

echo "Moving the fresh pulseaudio configuration directory..."
mv "$HOME/.config/pulse" "$HOME/.config/pulse.old"

echo "Restarting bluetooth..."
# systemctl might not have effect on bluetooth after the
# first start of OS, so rfkill is also used:
rfkill block bluetooth
sudo systemctl start bluetooth.service
rfkill unblock bluetooth
sudo systemctl stop bluetooth.service

echo "Starting pulseaudio after changing settings..."
systemctl --user start pulseaudio.socket
systemctl --user start pulseaudio.service

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            7. CAMERA CONTROLS                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="camera controls"
# DOCUMENTATION:
#   https://github.com/soyersoyer/cameractrls

informAboutProcedureStart

sudo apt install libsdl2-2.0-0 libturbojpeg -y

cameractrlsDir="$HOME/.cameractrls"

if [ -d "$cameractrlsDir" ]
  then
    echo "Old cameractrls directory found. Removing..."
    trash-put "$cameractrlsDir"
fi

echo "Creating a directory for cameractrls..."
mkdir -p "$cameractrlsDir"

echo "Cloning the repository with the program..."
git clone https://github.com/soyersoyer/cameractrls.git "$cameractrlsDir"

echo "Installing the program..."
desktop-file-install --dir="$HOME/.local/share/applications" \
--set-icon="$cameractrlsDir/images/icon_256.png" \
--set-key=Exec --set-value="$cameractrlsDir/cameractrlsgtk.py" \
--set-key=Path --set-value="$cameractrlsDir" \
"$cameractrlsDir/cameractrls.desktop"

sleep 5 # let the desktop application start up

echo "Configuring the camera Razer Kiyo Pro..."
# 1. The command below configures Razer Kiyo Pro.
# 2. Camera ID used in the command below stays the same across
#    different machines (usb-Razer_Inc_Razer_Kiyo_Pro-video-index0).
# 3. Settings will be saved and then have effect even if during
#    execution of the command below the camera wasn't connected.
"$cameractrlsDir/cameractrls.py" \
-d /dev/v4l/by-id/usb-Razer_Inc_Razer_Kiyo_Pro-video-index0 \
-c brightness=128,contrast=128,saturation=149,sharpness=137

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               7. REPO (AEM)                                 #
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
#                          7. FERNFLOWER (DECOMPILER)                         #
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

fernflowerInstallDir="/usr/share/java/fernflower"
fernflowerJarSourceAbs="$resourcesDir/fernflower/fernflower.jar"

if [ -d "$fernflowerInstallDir" ] || [ -f "$fernflowerInstallDir" ]
  then
    echo "Installation path is occupied. Removing in order to recreate: $fernflowerInstallDir..."
    sudo trash-put "$fernflowerInstallDir"
fi

echo "Creating an installation directory: $fernflowerInstallDir..."
sudo mkdir -p "$fernflowerInstallDir"

echo "Mounting a fernflower jar..."
# Note that the path to the target file
# (/usr/share/java/fernflower/fernflower.jar) is hardcoded in xplr:
sudo cp "$fernflowerJarSourceAbs" "$fernflowerInstallDir"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                   7. HOME DEFAULT DIRECTORIES CLEANING                      #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="home default directories cleaning"
# DOCUMENTATION:
#   n/a
# NOTES:
#   1. $HOME contains number of default directories. Some of them are useless and
#      can be removed (Templates, Public, Documents, Music, Videos).
#   2. Default directories are controlled by `~/.config/user-dirs.dirs`, where active (not commented out)
#      lines determine what directories are visible in $HOME. However, mere changing the content
#      of that file isn't enough, since after restarting the session the file gets reverted to the
#      original content by the file `/etc/xdg/user-dirs.defaults`. Therefore, useless default
#      directories should be removed from both those files.

informAboutProcedureStart

echo "Setting up variables..."
localDefaultDirsConfigFile="$HOME/.config/user-dirs.dirs"
globalDefaultDirsConfigFile="/etc/xdg/user-dirs.defaults"

echo "Enabling writing permissions for configuration files..."
sudo chmod 755 "$localDefaultDirsConfigFile"
sudo chmod 755 "$globalDefaultDirsConfigFile"

echo "Modifying the local configuration file..."
# Escaping $HOME below to let it be expanded in a file:
cat > "$localDefaultDirsConfigFile" << EOF
XDG_DESKTOP_DIR="\$HOME/Desktop"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
#XDG_TEMPLATES_DIR="\$HOME/Templates"
#XDG_PUBLICSHARE_DIR="\$HOME/Public"
#XDG_DOCUMENTS_DIR="\$HOME/Documents"
#XDG_MUSIC_DIR="\$HOME/Music"
XDG_PICTURES_DIR="\$HOME/Pictures"
#XDG_VIDEOS_DIR="\$HOME/Videos"
EOF

echo "Modifying the global configuration file..."
sudo bash -c "cat > ${globalDefaultDirsConfigFile} << EOF
DESKTOP=Desktop
DOWNLOAD=Downloads
#TEMPLATES=Templates
#PUBLICSHARE=Public
#DOCUMENTS=Documents
#MUSIC=Music
PICTURES=Pictures
#VIDEOS=Videos
# Another alternative is:
#MUSIC=Documents/Music
#PICTURES=Documents/Pictures
#VIDEOS=Documents/Videos
EOF
"

echo "Removing unnecessary directories..."
trash-put "$HOME/Templates"
trash-put "$HOME/Public"
trash-put "$HOME/Documents"
trash-put "$HOME/Music"
trash-put "$HOME/Videos"

echo "Removing deleted directories from bookmarks in the sidebar..."
bookmarksHolder="$HOME/.config/gtk-3.0/bookmarks"
echo "" > "$bookmarksHolder"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                7. APT REFRESH                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="apt refresh"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Disabling Ubuntu Software GUI automatic apt refresh..."
# Docs for the following: https://linuxconfig.org/disable-automatic-updates-on-ubuntu-22-04-jammy-jellyfish-linux
aptUpdateConfigFile="/etc/apt/apt.conf.d/20auto-upgrades"
sudo bash -c "cat > ${aptUpdateConfigFile} << EOF
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Download-Upgradeable-Packages \"0\";
APT::Periodic::AutocleanInterval \"0\";
APT::Periodic::Unattended-Upgrade \"0\";
EOF
"
# Docs for the following: https://unix.stackexchange.com/a/675685
sudo bash -c 'echo "Hidden=true" >> /etc/xdg/autostart/update-notifier.desktop'

# Docs for the following: https://askubuntu.com/questions/1059971/disable-updates-from-command-line-in-ubuntu-16-04?noredirect=1&lq=1
aptUpdateTriggerFile="/etc/cron.daily/apt-compat"
sudo sed -i 's=exec /usr/lib/apt/apt.systemd.daily=# exec /usr/lib/apt/apt.systemd.daily=g' "$aptUpdateTriggerFile"

# Docs for the following: https://www.linuxfordevices.com/tutorials/linux/automatic-updates-cronjob
echo "2. Enabling cron-based automatic apt refresh..."

scriptsDir="$HOME/scripts"

if [ ! -d "$scriptsDir" ]
  then
    echo "Scripts directory not found. Creating: $scriptsDir"
    mkdir -p "$scriptsDir"
fi

aptRefreshScript="$scriptsDir/apt_refresh.sh"

echo "Setting up regular apt refresh in /etc/crontab..."
# 1. `bash` after `root` is required: https://stackoverflow.com/questions/18809614/execute-a-shell-script-in-current-shell-with-sudo-permission
# 2. `cron` job will be run every Monday at 14:00
# 3. Logs are saved on Desktop to notify about the apt refresh. They can be removed right away after verifying them
sudo bash -c "cat >> /etc/crontab << EOF
0 14 * * 1 root bash $aptRefreshScript >> \"$HOME/Desktop/aptCronUpdate.log\"
EOF
"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               7. LID CLOSING                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="lid closing"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Changes will come into force after rebooting

informAboutProcedureStart

echo "Disabling actions triggered by lid closing..."
systemdLoginConfigFile="/etc/systemd/logind.conf"
sudo bash -c "cat > ${systemdLoginConfigFile} << EOF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                7. KEYCHRON                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="keychron"
# DOCUMENTATION:
#   https://gist.github.com/andrebrait/961cefe730f4a2c41f57911e6195e444
# NOTES:
#   Changes will come into force after rebooting

informAboutProcedureStart

echo "1. Setting up a configuration file..."
keyChronConfigFile="/etc/modprobe.d/hid_apple.conf"
if [ ! -f "$keyChronConfigFile" ]
  then
    sudo touch "$keyChronConfigFile"
fi
sudo bash -c "cat > ${keyChronConfigFile} << EOF
options hid_apple fnmode=2
EOF
"

echo "2. Updating initramfs..."
sudo update-initramfs -u

echo "Changes will come into force after rebooting."

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                7. WALLPAPER                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="wallpaper"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Setting up variables..."
wallpaperFileName="background.png"
wallpaperDestinationDir="$HOME/Pictures"
wallpaperDestinationPath="$wallpaperDestinationDir/$wallpaperFileName"

echo "Cleaning the path for the wallpaper..."
if [ -f "$wallpaperDestinationPath" ]
  then
    trash-put "$wallpaperDestinationPath"
fi

echo "Copying the wallpaper to the destination directory..."
wallpaperResourcesPath="$resourcesDir/$wallpaperFileName"
cp -rf "$wallpaperResourcesPath" "$wallpaperDestinationDir"

echo "Setting up the wallpaper..."
dconf write /org/gnome/desktop/background/picture-uri "'$wallpaperDestinationPath'"
dconf write /org/gnome/desktop/screensaver/picture-uri "'$wallpaperDestinationPath'"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                        7. BLACK SCREEN BUG FIX                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="black screen bug fix"
# DOCUMENTATION:
#   https://askubuntu.com/questions/1341208/screen-share-show-black-screen-after-upgrade-from-ubuntu-20-10-to-21-04
# NOTES:
#   For Linux Ubuntu 21+ there is a bug so that there is a black screen
#   while screen sharing. The code below fixes it.

informAboutProcedureStart

echo "Enabling X org to fix the bug with black screen while screen sharing..."
displayManagerConfigFile="/etc/gdm3/custom.conf"

sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' "$displayManagerConfigFile"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            7. DCONF (VARIOUS SETTINGS)                      #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="dconf (various settings)"
# DOCUMENTATION:
#   n/a
# NOTES:
#   To dump into a file current settings: dconf dump / > desktopSettingsFile.txt

informAboutProcedureStart

echo "Loading settings from a file..."
desktopSettingsFile="$resourcesDir/desktopSettingsFile.txt"
dconf load / < "$desktopSettingsFile"

echo "There might be incorrect font in the terminal now. This should be fixed by reboot."

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               7. PANDOC                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="pandoc"
# DOCUMENTATION:
#   n/a
# NOTES:
#   1. General markup converter, i.a. for .doc -> .adoc conversions
#   2. Don't install from apt, because pandoc version in apt might be heavily outdated

informAboutProcedureStart

curl -s https://api.github.com/repos/jgm/pandoc/releases/latest \
| grep "browser_download_url.*pandoc.*amd64.deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -i -

pandocIntstallationFile=$(ls -1 pandoc*amd64.deb | head -n 1)
sudo dpkg -i "$pandocIntstallationFile"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               7. LOCALE                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="locale"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Setting up a GB locale. The setting will get into force after rebooting..."
localeFile="/etc/default/locale"
sudo bash -c "cat > ${localeFile} << EOF
LANG=en_US.UTF-8
LC_NUMERIC=en_GB.UTF-8
LC_TIME=en_GB.UTF-8
LC_MONETARY=en_GB.UTF-8
LC_PAPER=en_GB.UTF-8
LC_NAME=en_GB.UTF-8
LC_ADDRESS=en_GB.UTF-8
LC_TELEPHONE=en_GB.UTF-8
LC_MEASUREMENT=en_GB.UTF-8
LC_IDENTIFICATION=en_GB.UTF-8
EOF
"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                          7. STARTUP UBUNTU LOGO                             #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="startup ubuntu logo"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Removing Ubuntu logo from the startup screen..."
sudo trash-put /usr/share/plymouth/ubuntu-logo.png
# Without the removed file updates might not work correctly, so it is saved as empty:
sudo echo "" | sudo tee /usr/share/plymouth/ubuntu-logo.png > /dev/null

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  7. MYSQL                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="mysql"
# DOCUMENTATION:
#   1. https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-22-04
#   2. https://linuxhint.com/installing_mysql_workbench_ubuntu/

informAboutProcedureStart

echo "Installing MySQL Server..."
sudo apt install mysql-server -y
echo "Installing MySQL Workbench..."
sudo snap install mysql-workbench-community

echo "Connecting MySQL Workbench with password manager service..."
# Docs: https://stackoverflow.com/questions/42671914/mysql-workbench-not-saving-passwords-in-keychain
sudo snap connect mysql-workbench-community:password-manager-service :password-manager-service

echo "Altering the root user so that it can be used within MySQL Workbench..."
# Docs:
# 1. https://stackoverflow.com/questions/7864276/cannot-connect-to-database-server-mysql-workbench
# 2. https://trendoceans.com/how-to-resolve-cannot-connect-to-database-server-mysql-workbench/
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  7. NEOVIM                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="neovim"
# DOCUMENTATION:
#   https://www.lazyvim.org/
#   https://github.com/folke/tokyonight.nvim

informAboutProcedureStart

echo "Installing NeoVim..."
sudo snap install nvim --classic

echo "Installing LazyVim..."
mkdir -p "$HOME/.config/nvim"
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

echo "Setting light theme..."
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

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                    7. IMWHEEL (MOUSE SPEED CONFIGURATOR)                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="imwheel (mouse speed configurator)"
# DOCUMENTATION:
#   https://wiki.archlinux.org/title/IMWheel

informAboutProcedureStart

imwheelConfigFile="$HOME/.imwheelrc"
imwheelStartupFile="$HOME/.config/autostart/imwheel.desktop"
autostartDir="$HOME/.config/autostart"

echo "1. Removing imwheel if installed..."
sudo apt remove imwheel -y
if [ -f "$imwheelConfigFile" ]
 then
   echo "Old config file detected ($imwheelConfigFile). Removing..."
   trash-put "$imwheelConfigFile"
fi
if [ -f "$imwheelStartupFile" ]
 then
   echo "Old startup file detected ($imwheelStartupFile). Removing..."
   trash-put "$imwheelStartupFile"
fi

echo "2. Installing imwheel..."
sudo apt install imwheel -y

echo "3. Creating a configuration file..."
# [Button4, 5] and [Button5, 5] stand for speed, where the second number is speed rate:
touch "$imwheelConfigFile"
cat > "$imwheelConfigFile" << EOF
".*"
None,      Up,   Button4, 4
None,      Down, Button5, 4
Control_L, Up,   Control_L|Button4
Control_L, Down, Control_L|Button5
Shift_L,   Up,   Shift_L|Button4
Shift_L,   Down, Shift_L|Button5
EOF

echo "4. Creating a startup directory if doesn't exist..."
if [ ! -d "$autostartDir" ]
  then
    mkdir -p "$autostartDir"
fi

echo "5. Creating a startup file..."
touch "$imwheelStartupFile"
cat > "$imwheelStartupFile" << EOF
[Desktop Entry]
Type=Application
Exec=imwheel
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=imwheel
Name=imwheel
Comment[en_US]=
Comment=
EOF

echo "6. Starting imwheel..."
imwheel

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            8. XPLR (FILE EXPLORER)                          #
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
sudo rm --force /usr/bin/xplr
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
wget https://github.com/sayanarijit/xplr/releases/download/v0.20.2/xplr-linux.tar.gz
tar --verbose --extract --file xplr-linux.tar.gz
# On binary installation: https://askubuntu.com/a/993635
sudo install ./xplr /usr/bin
mkdir -p "$xplrSettingsDir"

echo "3. Composing a main configuration file..."
mainConfigurationFile=$resourcesDir/"xplr/HOME/.config/xplr/init.lua"

echo "3.1. Extracting an xplr version..." # docs: https://xplr.dev/en/post-install
xplrVersion=$(xplr --version | cut --delimiter ' ' --field 2) # result like: 0.19.0
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
cat "$resourcesDir/xplr/HOME/.config/xplr/3_custom_commands.lua" >> "$mainConfigurationFile"

echo "3.3. Applying general configurations..."
echo "" >> "$mainConfigurationFile"
cat "$resourcesDir/xplr/HOME/.config/xplr/4_general_config.lua" >> "$mainConfigurationFile"

echo "4. Copying the composed main configuration file to its destination"
cp -f "$mainConfigurationFile" "$HOME/.config/xplr"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                9. MIME APPS                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="mime apps"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

# Overwrites default values from /usr/share/applications/mimeinfo.cache:
echo "1. Setting up associations for mime types..."
echo "Creating a mime config file if doesn't exist..."
mimeConfigFile="$HOME/.config/mimeapps.list"
touch "$mimeConfigFile"

echo "Appending to the mime config file..."
# The file might already exist and might already have a '[Default Applications]' header
# (that header is necessary for the file to have effect). However, if that header is
# doubled, the file will still have the intended effect.
cat >> "$mimeConfigFile" << EOF
[Default Applications]
video/x-matroska=mpv.desktop
video/mp4=mpv.desktop
application/pdf=evinceindependent.desktop
application/json=nvim.desktop
application/x-shellscript=nvim.desktop
application/xml=nvim.desktop
text/english=nvim.desktop
text/javascript=nvim.desktop
text/plain=nvim.desktop
text/x-c++=nvim.desktop
text/x-c++hdr=nvim.desktop
text/x-c++src=nvim.desktop
text/x-c=nvim.desktop
text/x-chdr=nvim.desktop
text/x-csrc=nvim.desktop
text/x-java=nvim.desktop
text/x-makefile=nvim.desktop
text/x-moc=nvim.desktop
text/x-pascal=nvim.desktop
text/x-tcl=nvim.desktop
text/x-tex=nvim.desktop
EOF

echo "2. Overriding default neovim launcher..."
# Overrides the default launcher from /usr/share/applications/nvim.desktop
mkdir -p "$HOME/.local/share/applications"
nvimLauncher="$HOME/.local/share/applications/nvim.desktop"
touch "$nvimLauncher"
cat > "$nvimLauncher" << EOF
[Desktop Entry]
Name=Neovim
GenericName=Text Editor
Comment=Edit text files
TryExec=nvim
Exec=nvim %F
Terminal=true
Type=Application
Keywords=Text;editor;
Icon=nvim
Categories=Utility;TextEditor;
StartupNotify=false
MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
EOF

echo "3. Overwriting default evince launcher..."
# Modifies the default launcher from /usr/share/applications/org.gnome.Evince.desktop
# to run separately from the terminal (don't close evince when terminal where it
# was initiated is closed
mkdir -p "$HOME/.local/share/applications"
evinceLauncher="$HOME/.local/share/applications/evinceindependent.desktop"
touch "$evinceLauncher"
cat > "$evinceLauncher" << EOF
[Desktop Entry]
Name=Document Viewer
Comment=View multi-page documents
# Translators: Search terms to find this application. Do NOT translate or localize the semicolons! The list MUST also end with a semicolon!
Keywords=pdf;ps;postscript;dvi;xps;djvu;tiff;document;presentation;viewer;evince;
TryExec=evince
Exec=nohup evince %U
StartupNotify=true
Terminal=false
Type=Application
# Translators: Do NOT translate or transliterate this text (this is an icon file name)!
Icon=org.gnome.Evince
Categories=GNOME;GTK;Office;Viewer;Graphics;2DGraphics;VectorGraphics;
MimeType=application/pdf;application/x-bzpdf;application/x-gzpdf;application/x-xzpdf;application/x-ext-pdf;application/postscript;application/x-bzpostscript;application/x-gzpostscript;image/x-eps;image/x-bzeps;image/x-gzeps;application/x-ext-ps;application/x-ext-eps;application/illustrator;application/x-dvi;application/x-bzdvi;application/x-gzdvi;application/x-ext-dvi;image/vnd.djvu+multipage;application/x-ext-djv;application/x-ext-djvu;image/tiff;application/x-cbr;application/x-cbz;application/x-cb7;application/x-cbt;application/x-ext-cbr;application/x-ext-cbz;application/x-ext-cb7;application/x-ext-cbt;application/vnd.comicbook+zip;application/vnd.comicbook-rar;application/oxps;application/vnd.ms-xpsdocument;
X-Ubuntu-Gettext-Domain=evince
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             10. GITHUB CLI                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="github cli"
# DOCUMENTATION:
#   GitHub CLI installation: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
#   Caching credentials for GitHub CLI: https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git
# NOTES:
#   As of writing this script, the official method of GitHub CLI installation didn't work
#   (see the issue: https://github.com/cli/cli/issues/6175). For that reason the program
#   is installed below directly from official binaries.

informAboutProcedureStart

echo "1. Downloading GitHub CLI..."
curl -s https://api.github.com/repos/cli/cli/releases/latest \
| grep "browser_download_url.*gh.*amd64.deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -i -

echo "2. Installing GitHub CLI..."
ghCLIIntstallationFile=$(ls -1 gh*amd64.deb | head -n 1)
sudo dpkg -i "$ghCLIIntstallationFile"

printf "\n3. Caching credentials for GitHub CLI...\n"
echo "   Please perform manual login according to prompts in the terminal."
echo "   If prompted for your preferred protocol for Git operations, select HTTPS."
gh auth login # Two options will be prompted: GitHub + GitHub Enterprise. The first one should be selected.
# <--- here manual login in should be performed --->

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             11. INTELLIJ IDEA                               #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="intellij idea"
# DOCUMENTATION:
#   n/a
# NOTES:
#   1. Settings for IntelliJ IDEA are of two types: synchronizable and non-synchronizable.
#   2. Synchronizable settings are stored in a remote git repository and are automatically synced
#      once that repository is defined. Non-synchronizable settings are, in turn, stored only
#      locally (no option for syncing them) and should be done manually. The script embraces
#      both mentioned types settings.
#   3. The script below requires a number of manual actions. This is because IntelliJ IDEA
#      setup cannot be effectively automated in that scope (e.g. its behavior on first
#      run is often unpredictable and it doesn't have clear configuration files system).
#   4. Since IntelliJ IDEA 2022.3 there is an inbuilt option 'Setting Sync'. However, it
#      is very unstable, unpredictable and also doesn't perform sync of all settings.
#      Besides that, it is impossible to backup or see all settings synced by that
#      functionality, so there is a risk of loosing settings.

informAboutProcedureStart

echo "1. Setting up variables..."
projectName="demoproject"
tempProjectDir="$tempDir/$projectName"
jetbrainsCacheDir="$HOME/.cache/JetBrains"
jetbrainsConfigDir="$HOME/.config/JetBrains"
jetbrainsLocalDir="$HOME/.local/share/JetBrains"
launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"

printf "\n2. Purging IntelliJ IDEA if present...\n"

if [ -d "$jetbrainsCacheDir" ]
  then
    echo "Old cache directory found. Removing..."
    trash-put "$jetbrainsCacheDir"
fi

if [ -d "$jetbrainsConfigDir" ]
  then
    echo "Old config directory found. Removing..."
    trash-put "$jetbrainsConfigDir"
fi

if [ -d "$jetbrainsLocalDir" ]
  then
    echo "Old local share directory found. Removing..."
    trash-put "$jetbrainsLocalDir"
fi

sudo snap remove intellij-idea-ultimate

printf "\n3. Installing IntelliJ IDEA...\n"
sudo snap install intellij-idea-ultimate --classic

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

nohup "$launcherPath" nosplash "$tempProjectDir" > /dev/null 2>&1 &

printf "\n5. Perform initial settings...\n"
echo "   5.1. Accept user agreement if requested."
echo "   5.2. Choose 'Don't Send' for data sharing request."
echo "   5.3. Choose to trust projects in a temporary directory if asked."
echo "   5.4. Login to your JetBrains account if asked."
echo "Press Enter to continue..."
read voidInput

echo "6. Install manually the following IntelliJ IDEA plugins:"
echo "   - AEM IDE"
echo "   - AsciiDoc"
echo "   - CodeMetrics"
echo "   - IdeaVim"
echo "   - Luanalysis"
echo "   - MoveTab"
echo "   - OSGi"
echo "   - Python"
echo "   - Settings Repository"
echo "   - SonarLint"
echo "   - Statistic"
echo "   - VCL/Varnish Language"
echo "Press Enter to continue..."
read voidInput

echo "7. Perform synchronizable settings:"
echo "   Toolbar -> File -> Manage IDE Settings -> Settings repository"
echo "   -> Upstream URL [like: https://github.com/ciechanowiec/intellij_settings]"
echo "   -> Overwrite local"
echo "Press Enter to continue..."
read voidInput

echo "8. Restart IntelliJ IDEA"
echo "Press Enter to continue..."
read voidInput

echo "9. Perform non-synchronizable workspace settings:"
echo "   -> In the right toolbar perform 'hide' action on all icons"
echo "   -> Toolbar -> Window -> Store current layout as default"
echo "Press Enter to continue..."
read voidInput

echo "10. Perform non-synchronizable Git settings:"
echo "   Toolbar -> File -> New Projects Setup -> Settings for New Projects"
echo "   -> Version Control"
echo "   -> Confirmation"
echo "      -> When files are created: Do not add"
echo "      -> When files are deleted: Do not remove"
echo "Press Enter to continue..."
read voidInput

echo "11. Perform non-synchronizable Maven settings:"
echo "   Toolbar -> File -> New Projects Setup -> Settings for New Projects"
echo "   -> Build, Execution, Deployment"
echo "   -> Build Tools"
echo "   -> Maven"
echo "   -> Importing"
echo "      -> Check Automatically download 'Sources', 'Documentation', 'Annotations'"
echo "Press Enter to continue..."
read voidInput

echo "12. Perform non-synchronizable shell check settings."
echo "   -> Open in IntelliJ any Bash script with .sh extension."
echo "   -> Click 'Install' in the pop-up window above about shell check plugin."
echo "Press Enter to continue..."
read voidInput

echo "13. Setting up files templates (removing 'public' modifiers for java files)..."
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

echo "14. Setting up .ideavimrc file..."
ideavimrcFile="$HOME/.ideavimrc"
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
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             12. INPUT REMAPPER                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="input remapper"
# DOCUMENTATION:
#   https://github.com/sezanzeb/input-remapper
#   https://github.com/sezanzeb/input-remapper/blob/main/readme/usage.md
# NOTES:
#   1. In GUI the settings should be the following:
#      A. For MX Anywhere 2S Mouse:
#           Button SIDE -> Alt_L+Left
#           Button EXTRA -> Alt_L+Right
#      B. For Keychron K4 Keychron K4 (sic):
#           Alt L + Delete -> Alt_L+Insert
#      C. Remember to check the option "Autoload"
#   2. In case of problems with autostart, checkout the `data/input-remapper-autoload.desktop`
#      file from the source code.

informAboutProcedureStart

echo "Removing application if it is already installed..."
sudo input-remapper-control --command stop-all
sudo systemctl stop input-remapper
sudo apt remove input-remapper -y
inputRemapperConfigDir="$HOME/.config/input-remapper"
if [ -d "$inputRemapperConfigDir" ]
  then
    echo "Old configuration directory detected. Removing..."
    trash-put "$inputRemapperConfigDir"
fi

echo "Installing application..."
# The files downloaded below can be removed after installation
sudo apt install git python3-setuptools gettext -y
sudo apt install input-remapper -y

echo "Starting the application for a while to initialize the configuration directory..."
# Running in a new terminal, because doing it in the current might block it:
sudo gnome-terminal -- bash -c "input-remapper-gtk"
sleep 5;
sudo pkill input-remapper

echo "Creating a configuration directory if it doesn't exist..."
if [ ! -d "$HOME/.config/input-remapper/presets" ]
  then
    mkdir -p "$HOME/.config/input-remapper/presets"
fi

echo "Populating the basic configuration file with presets declaration..."
basicConfigFile="$HOME/.config/input-remapper/config.json"
touch "$basicConfigFile"
cat > "$basicConfigFile" << EOF
{
    "autoload": {
        "MX Anywhere 2S Mouse": "new preset",
        "Keychron K4 Keychron K4": "new preset"
    }
}
EOF

echo "Creating a keyboard preset..."
keyboardPresetDir="$HOME/.config/input-remapper/presets/Keychron K4 Keychron K4"
keyboardPresetConfigFile="$keyboardPresetDir/new preset.json"
if [ -d "$keyboardPresetDir" ]
  then
    echo "Old presets directory detected. Removing..."
    trash-put "$keyboardPresetDir"
fi
mkdir -p "$keyboardPresetDir"
cat > "$keyboardPresetConfigFile" << EOF
{
    "mapping": {
        "1,56,1+1,111,1": [
            "Alt_L+Insert",
            "keyboard"
        ]
    }
}
EOF

echo "Creating a mouse preset..."
mousePresetDir="$HOME/.config/input-remapper/presets/MX Anywhere 2S Mouse"
mousePresetConfigFile="$mousePresetDir/new preset.json"
if [ -d "$mousePresetDir" ]
  then
    echo "Old presets directory detected. Removing..."
    trash-put "$mousePresetDir"
fi
mkdir -p "$mousePresetDir"
cat > "$mousePresetConfigFile" << EOF
{
    "mapping": {
        "1,276,1": [
            "Alt_L+Right",
            "keyboard"
        ],
        "1,275,1": [
            "Alt_L+Left",
            "keyboard"
        ]
    }
}
EOF

echo "Restarting presets injection..."
sudo input-remapper-control --command stop-all
sudo systemctl stop input-remapper
# Run IR to trigger generation of $HOME/.config/input-remapper/xmodmap.json
# - without this file remapping will not work.
# Running in a new terminal, because doing it in the current might block it:
sudo gnome-terminal -- bash -c "input-remapper-gtk"
sleep 5;
sudo pkill input-remapper
sudo systemctl start input-remapper
sudo input-remapper-control --command start --device "Keychron K4 Keychron K4" --preset "new preset.json"
sudo input-remapper-control --command start --device "MX Anywhere 2S Mouse" --preset "new preset.json"
sudo input-remapper-control --command autoload

# The program behaves unpredictably and often it is impossible to initiate the injection
# automatically. For that reason manual intervention below is required:
echo "Open 'Input Remapper' program and click 'Apply' for the following devices having them connected:"
echo "   -> Keychron K4 Keychron K4"
echo "   -> MX Anywhere 2S Mouse"
echo "Press Entry when done."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            13. GNOME EXTENSIONS                             #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="gnome extensions"
# DOCUMENTATION:
#    How to manually install GNOME extensions: https://www.debugpoint.com/2021/10/manual-installation-gnome-extension/
# NOTES:
# 1. GNOME extensions have own increasing versions for different versions on GNOME Shell.
#    Usually, new versions of extensions don't have significant changes and extensions for
#    a given GNOME Shell version work correctly with other versions.
#    Extensions below have hardcoded references for their latest versions (as of date
#    when creating the references) for GNOME Shell 3.36 delivered with Ubuntu 20.04).
#    When updating the script for newer GNOME Shell and Ubuntu versions, those references
#    should be updated.
# 2. For GNOME extensions to start working, GNOME Session must be restarted. Currently,
#    there is no safe way to load new extensions without restarting the session.

informAboutProcedureStart

echo "1. Installing extensions wrapper..."
sudo apt install gnome-shell-extensions -y

echo "2. Creating a directory for extensions..."
extensionsDir="$HOME/.local/share/gnome-shell/extensions"
if [ -d "$extensionsDir" ]
  then
    echo "Old extensions directory detected. Removing..."
    trash-put "$extensionsDir"
fi
mkdir -p "$extensionsDir"

echo "3. Installing 'Panel Date Format' extension..."
# 1. Extension page: https://extensions.gnome.org/extension/1462/panel-date-format/
# 2. Configuration for this extension is made in a separate `dconf` procedure
panelDateFormatArchive="panelDateFormatArchive.zip"
wget -O "$panelDateFormatArchive" https://extensions.gnome.org/extension-data/panel-date-formatkeiii.github.com.v8.shell-extension.zip
panelDateFormatDirUnzipped="panelDateFormatDirUnzipped"
unzip "$panelDateFormatArchive" -d "$panelDateFormatDirUnzipped"
# Extract the UUID. It is stored in `metadata.json` file in the line like this:
#   "uuid": "panel-date-format@keiii.github.com",
panelDateFormatUUID=$(grep -o -P "(?<=\"uuid\": \").*(?=\",)" < "$panelDateFormatDirUnzipped/metadata.json")
mv "$panelDateFormatDirUnzipped" "$panelDateFormatUUID"
cp -rf "$panelDateFormatUUID" "$extensionsDir"

echo "4. Installing 'Just Perfection' extension..."
# 1. Extension page: https://extensions.gnome.org/extension/3843/just-perfection/
# 2. Configuration for this extension is made in a separate `dconf` procedure
justPerfectionArchive="justPerfectionArchive.zip"
wget -O "$justPerfectionArchive" https://extensions.gnome.org/extension-data/just-perfection-desktopjust-perfection.v22.shell-extension.zip
justPerfectionDirUnzipped="justPerfectionDirUnzipped"
unzip "$justPerfectionArchive" -d "$justPerfectionDirUnzipped"
# Extract the UUID. It is stored in `metadata.json` file in the line like this:
#   "uuid": "just-perfection-desktop@just-perfection",
justPerfectionUUID=$(grep -o -P "(?<=\"uuid\": \").*(?=\",)" < "$justPerfectionDirUnzipped/metadata.json")
echo "$justPerfectionUUID"
mv "$justPerfectionDirUnzipped" "$justPerfectionUUID"
cp -rf "$justPerfectionUUID" "$extensionsDir"

echo "5. Installing 'ddterm' extension..."
# 1. Extension page: https://extensions.gnome.org/extension/3780/ddterm/
# 2. Configuration for this extension is made in a separate `dconf` procedure
ddtermArchive="ddtermArchive.zip"
wget -O "$ddtermArchive" https://extensions.gnome.org/extension-data/ddtermamezin.github.com.v36.shell-extension.zip
ddtermDirUnzipped="ddtermDirUnzipped"
unzip "$ddtermArchive" -d "$ddtermDirUnzipped"
# Extract the UUID. It is stored in `metadata.json` file in the line like this:
#   "uuid": "ddterm@amezin.github.com",
ddtermUUID=$(grep -o -P "(?<=\"uuid\": \").*(?=\",)" < "$ddtermDirUnzipped/metadata.json")
mv "$ddtermDirUnzipped" "$ddtermUUID"
cp -rf "$ddtermUUID" "$extensionsDir"

echo "6. Enabling extensions. They will start working after GNOME session is restarted..."
dconf write /org/gnome/shell/enabled-extensions "['$panelDateFormatUUID', '$justPerfectionUUID', '$ddtermUUID']"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              13. ONLY OFFICE                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="only office"
# DOCUMENTATION:
#   n/a
# NOTES:
#   Consider the following settings:
#     File -> Advanced settings -> Proofing:
#     -> Math AutoCorrect -> uncheck "Replace text as you type"
#     -> AutoFormat As You Type -> uncheck all in "Apply As You Type"
#     -> Text AutoCorrect -> uncheck "Capitalize first letter of sentences"

informAboutProcedureStart

echo "Installing Only Office Desktop Editors..."
sudo snap install onlyoffice-desktopeditors

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            14. GOOGLE CHROME                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="google chrome"
# DOCUMENTATION:
#   n/a
# NOTES:
#   During Chrome installation there are a lot of `sleep` commands to give Chrome time to catch up.

informAboutProcedureStart

echo "Provide Google Chrome username:"
read googleChromeUsername

echo "Provide Google Chrome password:"
read -s googleChromePassword
echo ""

echo "Removing Chrome if installed..."
sudo apt remove google-chrome-stable -y
if [ -d "$HOME/.config/google-chrome" ]
  then
    trash-put "$HOME/.config/google-chrome"
fi
if [ -f google-chrome-stable_current_amd64.deb ]
  then
    trash-put google-chrome-stable_current_amd64.deb
fi

echo "Downloading a .deb package for Chrome..."
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

echo "Installing Chrome..."
sudo dpkg -i google-chrome-stable_current_amd64.deb

echo "Opening Chrome..."
nohup google-chrome > /dev/null 2>&1 &

echo "Closing pop-up settings on first Chrome run..."
sleep 4
xdotool key shift+Tab
xdotool key shift+Tab
xdotool key space
sleep 2
xdotool key Tab
xdotool key Tab
xdotool key space

echo "Signing in into Chrome account..."
sleep 4
xdotool key Tab
xdotool key Tab
xdotool key space
sleep 4
xdotool type "$googleChromeUsername"
xdotool key Tab
xdotool key Tab
xdotool key Tab
xdotool key space
sleep 4
xdotool type "$googleChromePassword"
sleep 2
xdotool key Tab
xdotool key Tab
xdotool key space

echo "Allowing the organization to manage the profile..."
sleep 7
xdotool key space

echo "Turning on syncing (it might take up to 1 minute)..."
sleep 4
xdotool key space
sleep 40 # Give time to download and sync settings

echo "Closing Chrome to modify the configuration file..."
# 1. Changing the configuration file should be done (i) after Chrome user is logged in
#    (logging updates the configuration file and might discard changes to it made before
#    logging) and (ii) when Chrome is closed (closing Chrome updates the configuration
#    file and might discard changes to it made when Chrome was running).
# 2. After closing Chrome, give it some time to overwrite the configuration file.
pkill chrome
sleep 4
echo "Hiding shortcuts on the main page..."
# 1. Value of "num_personal_suggestions" property might differ, but it
#    doesn't have practical relevant meaning, so it can be set to 1.
# 2. Name of "shortcust_visible" property has original typo inside. Don't change it.
chromeSettingsFile="$HOME/.config/google-chrome/Default/Preferences"
sed -i 's/"num_personal_suggestions":[[:digit:]]\+},/"num_personal_suggestions":1,"shortcust_visible":false},/g' "$chromeSettingsFile"
sed -i 's/"num_personal_suggestions":[[:digit:]]\+,"shortcust_visible":true},/"num_personal_suggestions":1,"shortcust_visible":false},/g' "$chromeSettingsFile"
echo "Turning on caret browsing..."
sed -i 's/},"sharing":{/},"settings":{"a11y":{"caretbrowsing":{"enabled":true,"show_dialog":false}}},"sharing":{/g' "$chromeSettingsFile"

echo "Give manually permissions for News Feed Eradicator..."
sleep 2
nohup google-chrome > /dev/null 2>&1 &
echo "   Press Entry when done."
read voidInput

# The Chrome settings are practically unpredictable when it comes to a default
# download directory, so it should be set manually:
echo "Set up manually in Chrome settings the default download directory..."
echo "   Press Entry when done."
read voidInput

echo "Closing Chrome..."
pkill chrome

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             15. NVIDIA DRIVERS                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="nvidia drivers"
# DOCUMENTATION:
#   https://github.com/NVIDIA/open-gpu-kernel-modules
# NOTES:
#   1. The NVIDIA driver version that is installed below was hardcoded. Due to stability
#      considerations, update of that hardcoded version should be done manually and tested.
#   2. To check whether drivers were installed correctly, run after installation
#      and rebooting the following command: `nvidia-smi`

informAboutProcedureStart

echo "1. Searching for NVIDIA devices..."
# If no devices were found, the command below will exit with code `1`
lspci -v | grep -i 'nvidia' &> /dev/null
exitCode=$?
if [ "$exitCode" != 0 ]
  then
    echo "2. No NVIDIA devices were found. No drivers will be installed"
  else
    echo "2. NVIDIA devices detected. Drivers will be installed now..."
    sudo add-apt-repository ppa:graphics-drivers/ppa -y
    sudo apt update
    sudo apt install nvidia-driver-525 -y
    echo "3. NVIDIA drivers installed. They will start after rebooting"
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  16. INSYNC                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="insync"
# DOCUMENTATION:
#   https://www.insynchq.com/downloads/linux

informAboutProcedureStart

echo "Downloading insync..."
wget https://cdn.insynchq.com/builds/linux/insync_3.8.4.50481-jammy_amd64.deb

echo "Installing insync..."
sudo dpkg -i insync_3.8.4.50481-jammy_amd64.deb

echo "Adjust manually InSync settings according to personal needs."
echo "Press Enter to continue..."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              16. CLEANUP                                    #
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
