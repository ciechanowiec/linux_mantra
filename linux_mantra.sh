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
#                              2. BASIC UTILS                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="basic utils"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Installing curl (transfer a URL)..."
# Don't install curl via snap - it might work incorrectly then
sudo apt install curl -y

echo "Installing tree (list contents of directories in a tree-like format)..."
sudo apt install tree -y

echo "Installing unzip (file decompressor)..."
sudo apt install unzip -y

echo "Installing p7zip (file decompressor)..."
sudo apt install p7zip-full -y

echo "Installing wget (non-interactive network downloader)..."
sudo apt install wget -y

echo "Installing usb-creator-gtk (startup disk creator)..."
sudo apt install usb-creator-gtk -y

echo "Installing vim (terminal-based text editor)..."
sudo apt install vim -y

echo "Installing pip (tool for installing and managing Python packages)..."
sudo apt install python3-pip -y

echo "Installing htop (interactive process viewer)..."
sudo apt install htop -y

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

echo "Installing vale (syntax-aware linter for prose)..."
sudo apt install vale -y

echo "Installing ruby (interpreted object-oriented scripting language)..."
sudo apt install ruby -y

echo "Installing asciidoctor (asciidoc processor)..."
sudo apt install asciidoctor -y

echo "Installing wavemon (Wi-Fi connection monitor)..."
sudo apt install wavemon -y

echo "Installing inkskape (svg editor)..."
sudo apt install inkscape -y

echo "Installing libreoffice (word processor)..."
sudo apt install libreoffice -y

echo "Installing exiftool (read and write meta information in files)"
sudo apt install exiftool -y

echo "Installing tesseract (command-line OCR engine)"
# Docs: https://tesseract-ocr.github.io/tessdoc/Installation.html
sudo apt install tesseract-ocr -y
sudo apt install libtesseract-dev -y

echo "Installing imagemagick (images converter)"
sudo apt install imagemagick -y

echo "Installing fuse (enables filesystems in userspace)"
sudo apt install fuse -y

echo "Installing libfuse2 (library for fuse functionalities)"
sudo apt install libfuse2 -y

echo "Installing nvtop (top for nvidia GPU)"
sudo apt install nvtop -y

echo "Installing gnome-control-center (GUI for settings)"
# Sometimes GUI for settings might miss (https://stackoverflow.com/a/75132841)
sudo apt install gnome-control-center

echo "Installing yt-dlp (YouTube downloader)..."
# 1. Do not perform installation via other package managers - the program might not work correctly then
# 2. Do not perform installation with sudo - it might not - the program might not work correctly then
sudo apt remove yt-dlp -y
pip3 install yt-dlp --no-warn-script-location

# Consider the following settings Only Office Desktop Editors:
#   File -> Advanced settings -> Proofing:
#   -> Math AutoCorrect -> uncheck "Replace text as you type"
#   -> AutoFormat As You Type -> uncheck all in "Apply As You Type"
#   -> Text AutoCorrect -> uncheck "Capitalize first letter of sentences"
echo "Installing onlyoffice-desktopeditors (word processor)..."
sudo snap install onlyoffice-desktopeditors

echo "Installing vidcutter (video cutter)..."
# DOCUMENTATION: https://github.com/ozmartian/vidcutter
sudo snap install vidcutter

echo "Installing postman (app for building and using APIs)..."
sudo snap install postman

echo "Installing node (server environment)..."
# Installation docs:
#   https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
#   https://github.com/nodejs/snap
#   https://snapcraft.io/node
sudo snap install node --classic

echo "Installing TypeScript..."
# Installation docs:
#   bad: https://www.typescriptlang.org/download
#   good: https://lindevs.com/install-typescript-on-ubuntu
sudo npm install -g typescript # `npm` comes from node, so node must be preinstalled

echo "Installing Mermaid CLI (diagramming tool)..."
sudo npm install -g @mermaid-js/mermaid-cli

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           3. NIX PACKAGE MANAGER                            #
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
#                                  4. GIT                                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="git"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "1. Installing git..."
sudo apt install git -y

echo "2. Setting 'main' as the default branch name..."
git config --global init.defaultBranch main

echo "3. Setting up a global git committer..."
echo "Enter global git committer name (first name and surname, eg. John Doe):"
read committerName
echo "Enter global git committer email:"
read committerEmail
git config --global user.name "$committerName"
git config --global user.email "$committerEmail"

echo "4. Disabling pagination for branch listing..."
# Docs: https://stackoverflow.com/a/48370253
git config --global pager.branch false

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                        5. HOMEBREW PACKAGE MANAGER                          #
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
#                                 6. VIM                                      #
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
    activate application "iTerm"
else
    tell application "iTerm"
      create window with default profile
      activate
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

echo "11. Sourcing .vimrc file..."
nvimInitFile="$HOME/.config/nvim/init.lua"
cat >> "$nvimInitFile" << EOF

vim.cmd('source ~/.vimrc')
EOF

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  7. SHELL                                   #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="shell"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

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
sed -i "s/$escapedOldPrompt/$escapedNewPrompt/g" "$shellFile"

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
sed -i "s/$escapedOldTabName/$escapedNewTabName/g" "$shellFile"

echo "3. Making * to include hidden files..."
# Details on the change: https://askubuntu.com/questions/259383/how-can-i-get-mv-or-the-wildcard-to-move-hidden-files
cat >> "$shellFile" << EOF

# MAKING * TO INCLUDE HIDDEN FILES:
shopt -s dotglob
EOF

echo "4. Copying bash scripts..."
sourceDirWithScripts="$resourcesDir/scripts"
targetDirWithScripts="$HOME/scripts"
mkdir -p "$targetDirWithScripts"
cp -f "$sourceDirWithScripts"/* "$targetDirWithScripts"

echo "5.1. Setting up UNIX aliases..."
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

echo "5.2. Setting up Linux aliases..."
cat >> "$shellFile" << EOF

# LINUX ALIASES:
alias e="edge"
alias edge="(nohup microsoft-edge > /dev/null 2>&1 & disown)"
alias logout="pkill -KILL -u $(whoami)"
alias scaling="dconf write /org/gnome/desktop/interface/text-scaling-factor" # Usage: 'scaling 1.0', 'scaling 1.4' (range from 0 to 2)
alias shutdown="shutdown now"
alias xxclip="perl -pe 'chomp if eof' | xclip -selection clipboard" # perl is required to drop the last NL character
fuse() {
    fuser --kill --namespace tcp "$1"
}
EOF

echo "6. Adding GitHub CLI autocompletion..."
# Docs: https://cli.github.com/manual/gh_completion
cat >> "$shellFile" << EOF

# GH CLI AUTOCOMPLETION:
eval "\$(gh completion -s bash)"
EOF

echo "7. Adding local bin to PATH..."
echo "export PATH=\"\$PATH:\$HOME/.local/bin\"" >> "$shellFile"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                              8. TERRAFORM                                   #
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
#                             9. AZURE CLI                                    #
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
#                                10. RUST                                     #
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
#                               11. SDKMAN                                    #
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
#                               11.1. JAVA                                    #
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
#                               11.2. MAVEN                                   #
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
#                            11.3. SPRING BOOT                                #
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
#                                12. FONTS                                    #
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

echo "4. Retrieving new fonts..."
fontOne="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Regular/JetBrainsMonoNLNerdFontMono-Regular.ttf"
fontTwo="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Bold/JetBrainsMonoNLNerdFontMono-Bold.ttf"
fontThree="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/NoLigatures/Italic/JetBrainsMonoNLNerdFontMono-Italic.ttf"
wget "$fontOne" -P tempFontsDir
wget "$fontTwo" -P tempFontsDir
wget "$fontThree" -P tempFontsDir
# Google's API for downloading Noto Serif is subject to constant changes, so the font is stored locally: 
unzip "$resourcesDir/font/noto_serif.zip" -d noto_serif 
cp -rf noto_serif/static/NotoSerif-Bold.ttf \
  noto_serif/static/NotoSerif-Italic.ttf \
  noto_serif/static/NotoSerif-BoldItalic.ttf \
  noto_serif/static/NotoSerif-Regular.ttf \
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
#                              12. FIREWALL                                   #
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
#                               12. 0_PROG                                    #
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
#                                  12. DOCKER                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="docker"
# DOCUMENTATION:
#   n/a

informAboutProcedureStart

echo "Stopping Docker..."
sudo systemctl stop docker.socket
sudo systemctl stop docker.service

echo "Uninstalling Docker related to Docker Engine..."
sudo apt remove docker.io docker-compose docker-compose-v2 docker-doc podman-docker -y
sudo apt remove docker docker-engine containerd runc -y
sudo apt remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
rm -r "$HOME/.docker"

echo "Uninstalling Docker related to Docker Desktop..."
sudo apt remove docker-desktop -y
sudo rm /usr/local/bin/com.docker.cli

echo "Uninstalling Docker related to Docker Compose..."
sudo apt remove docker-compose-plugin -y
rm "$DOCKER_CONFIG/cli-plugins/docker-compose"
rm /usr/local/lib/docker/cli-plugins/docker-compose

echo "Uninstalling Docker from snap..."
sudo snap remove docker

echo "Setting up the repository..."
sudo apt update -y
sudo apt install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y

echo "Installing Docker Engine and Docker Compose..."
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

while true; do
  read -p "Do you want to log in to Docker Hub (this is not obligatory for Docker to work)? (Y/n): " choice
  choice=${choice:-Y} # Default to "Y" if Enter is pressed
  case "$choice" in
    [Yy]* )
      if ! sudo -n true 2>/dev/null; then
        echo "Provide your sudo password to continue"
        sudo -v
        if [ $? -ne 0 ]; then
          echo "Failed to authenticate with sudo. Exiting."
          exit 1
        fi
      fi
      echo "Logging out from Docker Hub..."
      docker logout
      echo "Logging into Docker Hub..."
      echo "Provide your Docker Hub login:"
      read -r dockerHubLogin
      echo "Provide your Docker Hub password"
      sudo docker login --username "$dockerHubLogin"
      exitCode=$?

      while [ "$exitCode" -ne 0 ]; do
        echo "Invalid password. Please try again."
        echo "Provide your Docker Hub login:"
        read -r dockerHubLogin
        sudo docker login --username "$dockerHubLogin"
        exitCode=$?
      done
      break
      ;;
    [Nn]* )
      break
      ;;
    * )
      echo "Invalid state"
      ;;
  esac
done

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         12. PULSEAUDIO BUG FIX                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="pulseaudio bug fix"
# DOCUMENTATION:
#   https://askubuntu.com/questions/1232159/ubuntu-20-04-no-sound-out-of-bluetooth-headphones
# NOTES:
#   Fix bluetooth audio issues related to pulseaudio
#   The fix might be unstable

informAboutProcedureStart

echo "Reinstalling pulseaudio..."
sudo apt install --reinstall pulseaudio pulseaudio-module-bluetooth -y

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
sudo systemctl stop bluetooth.service
rfkill unblock bluetooth
sudo systemctl start bluetooth.service

echo "Starting pulseaudio after changing settings..."
systemctl --user start pulseaudio.socket
systemctl --user start pulseaudio.service

echo "Reloading the daemons..."
systemctl --user daemon-reload # Command suggested by the hints from the commands above

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            12. CAMERA CONTROLS                              #
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
  --set-key=Exec --set-value="$cameractrlsDir/cameractrlsgtk4.py" \
  --set-key=Path --set-value="$cameractrlsDir" \
  --set-key=Icon --set-value="$cameractrlsDir/pkg/hu.irl.cameractrls.svg" \
  "$cameractrlsDir/pkg/hu.irl.cameractrls.desktop"

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
#                               12. REPO (AEM)                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="repo (aem)"
# DOCUMENTATION:
#   https://github.com/Adobe-Marketing-Cloud/tools/tree/master/repo

informAboutProcedureStart

echo "Installing a repo tool for AEM..."
brew tap adobe-marketing-cloud/brews
brew install adobe-marketing-cloud/brews/repo

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                         12. FERNFLOWER (DECOMPILER)                         #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="fernflower (decompiler)"
# DOCUMENTATION:
#   https://github.com/fesh0r/fernflower
# NOTES:
#   1. CFR (https://github.com/leibnitz27/cfr) decompiler was also tested, but it
#      extracted only Java files, discarding META-INF, resources, etc.
#   2. The installation is performed via mounting a `fernflower.jar` file stored in
#      the Linux Mantra repository. That file is a custom build from the source code
#      (https://github.com/fesh0r/fernflower) based on the
#      e52e88a7488d02fae7dd94291e62877954efcd10 commit from 2023-10-03 (14:39, +0200).

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
#                   12. HOME DEFAULT DIRECTORIES CLEANING                     #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="home default directories cleaning"
# DOCUMENTATION:
#   n/a
# NOTES:
#   1. $HOME contains a number of default directories. Some of them are
#      useless and can be removed (Templates, Public, Documents, Music, Videos).
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
#                               12. APT REFRESH                               #
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
#                              12. LID CLOSING                                #
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
#                                12. KEYCHRON                                 #
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
#                               12. WALLPAPER                                 #
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
#                        12. BLACK SCREEN BUG FIX                             #
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
#                           12. DCONF (VARIOUS SETTINGS)                      #
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
desktopSettingsFile="$resourcesDir/linux/desktopSettingsFile.txt"
dconf load / < "$desktopSettingsFile"

echo "There might be incorrect font in the terminal now. This should be fixed by reboot."

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                               12. PANDOC                                    #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="pandoc"
# DOCUMENTATION:
#   n/a
# NOTES:
#   1. General markup converter, i.a. for .doc -> .adoc conversions
#   2. Don't install from apt, because pandoc version in apt might be heavily outdated
#   3. Don't install from brew, because it comes with no autocompletion by default

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
#                               12. LOCALE                                    #
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
#                          12. STARTUP UBUNTU LOGO                            #
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
#                    12. IMWHEEL (MOUSE SPEED CONFIGURATOR)                   #
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
# [Button4, 3] and [Button5, 3] stand for speed, where the second number is speed rate:
touch "$imwheelConfigFile"
cat > "$imwheelConfigFile" << EOF
".*"
None,      Up,   Button4, 3
None,      Down, Button5, 3
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
#                           12. XPLR (FILE EXPLORER)                          #
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

echo "5. Cleaning the main configuration file..."
echo "" > "$mainConfigurationFile"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             12. MIME ASSOCIATIONS                           #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="mime associations"
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
# was initiated is closed)
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
#                             13. GITHUB CLI                                  #
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
#                             14. INTELLIJ IDEA                               #
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
#                             15. INPUT REMAPPER                              #
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

inputRemapperConfigDir="$HOME/.config/input-remapper"

echo "Removing application if it is already installed..."
sudo input-remapper-control --command stop-all
sudo systemctl stop input-remapper
sudo apt remove input-remapper -y
if [ -d "$inputRemapperConfigDir" ]
  then
    echo "Old configuration directory detected. Removing..."
    trash-put "$inputRemapperConfigDir"
fi

echo "Installing application..."
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
echo "Press Enter to continue"
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            16. GNOME EXTENSIONS                             #
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
#    when creating the references) for GNOME Shell 42.9 delivered with Ubuntu 22.04).
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
wget -O "$panelDateFormatArchive" https://extensions.gnome.org/extension-data/panel-date-formatkeiii.github.com.v11.shell-extension.zip
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
wget -O "$justPerfectionArchive" https://extensions.gnome.org/extension-data/just-perfection-desktopjust-perfection.v26.shell-extension.zip
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
wget -O "$ddtermArchive" https://extensions.gnome.org/extension-data/ddtermamezin.github.com.v53.shell-extension.zip
ddtermDirUnzipped="ddtermDirUnzipped"
unzip "$ddtermArchive" -d "$ddtermDirUnzipped"
# Extract the UUID. It is stored in `metadata.json` file in the line like this:
#   "uuid": "ddterm@amezin.github.com",
ddtermUUID=$(grep -o -P "(?<=\"uuid\": \").*(?=\",)" < "$ddtermDirUnzipped/metadata.json")
mv "$ddtermDirUnzipped" "$ddtermUUID"
cp -rf "$ddtermUUID" "$extensionsDir"

echo "6. Enabling extensions. They will start working after GNOME session is restarted..."
dconf write /org/gnome/shell/enabled-extensions "['$panelDateFormatUUID', '$justPerfectionUUID', '$ddtermUUID']"

echo "7. Disabling extensions update notifications..."
# https://gitlab.com/thjderjktyrjkt/disable-gnome-extension-update-check
# https://unix.stackexchange.com/a/747690
git clone https://gitlab.com/thjderjktyrjkt/disable-gnome-extension-update-check.git "$HOME/.local/share/gnome-shell/extensions/disable-gnome-extension-update-check@thjderjktyrjkt.gitlab.com"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                           17. MICROSOFT EDGE                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="microsoft edge"
# DOCUMENTATION:
#   https://www.omgubuntu.co.uk/2021/01/how-to-install-edge-on-ubuntu-linux
# NOTES:
#   Automation of browser settings isn't reasonable because of dynamic nature of the application.
#   Attempts for such automation were made, but the solution wasn't sustainable and reproducible
#   to the satisfying extent

informAboutProcedureStart

echo "Setting up an apt Microsoft repository..."
curl --verbose https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install --owner root --group root --mode 644 microsoft.gpg /etc/apt/trusted.gpg.d
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge-dev.list'
sudo rm microsoft.gpg

echo "Updating apt repositories..."
sudo apt update

echo "Installing Microsoft Edge..."
sudo apt install microsoft-edge-stable

echo "Microsoft Edge will be opened now..."
(nohup microsoft-edge > /dev/null 2>&1 & disown)

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
pkill edge

echo "Removing redundant repository added by Microsoft..."
sudo trash-put /etc/apt/sources.list.d/microsoft-edge-dev.list

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                             18. NVIDIA DRIVERS                              #
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
    sudo apt install nvidia-driver-550 -y
    echo "3. NVIDIA drivers installed. They will start after rebooting"
fi

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                  19. INSYNC                                 #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="insync"
# DOCUMENTATION:
#   https://www.insynchq.com/downloads/linux

informAboutProcedureStart

installFile="insync_3.8.6.50504-jammy_amd64.deb"

echo "Downloading insync..."
wget "https://cdn.insynchq.com/builds/linux/$installFile"

echo "Installing insync..."
sudo dpkg -i "$installFile"

echo "Adjust manually InSync settings according to personal needs."
echo "Press Enter to continue..."
read voidInput

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            19. PROFILE IMAGE                                #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="profile image"
# DOCUMENTATION:
#   https://www.reddit.com/r/linuxquestions/comments/qfcfob/changing_profile_picture_of_a_user_via_terminal/hhys289/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

informAboutProcedureStart

echo "Setting up a profile image..."
photoSourcePath="$resourcesDir/avatar.jpg"
photoTargetPath="$HOME/Pictures/avatar.jpg"
sudo apt install imagemagick
convert "$photoSourcePath" -resize 500x500 "$photoTargetPath"
userID=$(id -u "$(whoami)")
busctl call \
    org.freedesktop.Accounts \
    /org/freedesktop/Accounts/User"$userID" \
    org.freedesktop.Accounts.User \
    SetIconFile \
    s "$photoTargetPath"

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                            7. COMMON REPOS                                  #
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
