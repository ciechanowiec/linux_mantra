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
expectedLinuxReleaseName="resolute"
expectedMacReleaseName="macOS 26"

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

echo "4.1. Verifying that this script matches the detected operating system..."
if [ "$isLinux" == true ];
  then
    echo "mac_mantra.sh is intended for macOS, but Linux was detected. Run linux_mantra.sh instead. Exiting..."
    exit 1
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
      # macOS perpetually re-offers "Command Line Tools for Xcode" as an available
      # (and even Recommended) update, so --all / --recommended re-download and
      # reinstall it on every run. Install updates by label, skipping that entry.
      echo "5.1. Collecting available updates..."
      updateLabels=$(softwareupdate --list 2>/dev/null \
        | grep -E '^[[:space:]]*\* Label:' \
        | sed -E 's/^[[:space:]]*\* Label: //' \
        | grep -v 'Command Line Tools')
      if [ -z "$updateLabels" ];
        then
          echo "5.2. No applicable updates found"
        else
          echo "5.2. Installing available updates..."
          while IFS= read -r updateLabel; do
            echo "Installing: $updateLabel"
            softwareupdate --verbose --install "$updateLabel"
          done <<< "$updateLabels"
      fi
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
alias mantra_ts='~/scripts/mantra_ts.sh'
alias mantra_docs='~/scripts/mantra_docs.sh'
alias mvn_download_sources_and_javadocs='mvn dependency:sources && mvn dependency:sources dependency:resolve -Dclassifier=javadoc'
alias n='nvim'
alias nvim="~/scripts/nvim.sh"
alias p='pnpm'
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
    if [ -z "\$1" ]; then
        echo "Usage: fuse <port>"
        return 1
    fi
    local pids
    pids=\$(lsof -ti tcp:"\$1")
    if [ -n "\$pids" ]; then
        echo "Killing processes on port \$1:"
        echo "\$pids" | while read -r pid; do
            kill -9 "\$pid" && echo "Killed process \$pid"
        done
    else
        echo "No process found on port \$1"
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

echo "12. Fixing GPG bug..."
cat >> "$shellFile" << EOF

# Fix GPG bug:
# Docs: https://github.com/keybase/keybase-issues/issues/2798
export GPG_TTY=\$(tty)
EOF

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
# Register Homebrew BEFORE oh-my-zsh's `source` line so oh-my-zsh's single compinit picks
# up brew completions. Appending a brew block with its own `compinit` AFTER oh-my-zsh (the
# previous approach) ran compinit twice and re-scanned/re-dumped the completion cache on
# every shell start, adding ~1s to startup; reruns of this procedure stacked even more.
sed -i.backup '/source \$ZSH\/oh-my-zsh.sh/i\
# Homebrew (before oh-my-zsh so its single compinit registers brew completions):\
eval "$(/opt/homebrew/bin/brew shellenv)"\
FPATH="/opt/homebrew/share/zsh/site-functions:${FPATH}"
' "$shellFile"
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
#                          5.1. GOOGLE CLOUD CLI                              #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="google cloud cli"
# DOCUMENTATION:
#   https://cloud.google.com/sdk/docs/install#mac
#   https://formulae.brew.sh/cask/gcloud-cli
# NOTES:
#   Google's primary install method on macOS is the tarball installer; the
#   Homebrew cask is officially listed as an alternative and is used here for
#   consistency with the rest of this script (which is brew-based on macOS).

echo "1. Installing Google Cloud CLI..."
brew update && brew install --cask gcloud-cli

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
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    # The SDKMAN installer hard-requires Bash 4+, but macOS ships Bash 3.2, so
    # the installer must be run under a modern Bash. Homebrew's Bash (assumed to
    # be already installed) provides it. `brew install bash` is idempotent:
    echo "1.1. Ensuring a modern Bash via Homebrew (macOS ships Bash 3.2, SDKMAN needs Bash 4+)..."
    brew install bash
    echo "1.2. Installing SDKMAN with Homebrew's Bash..."
    curl -s "https://get.sdkman.io" | "$(brew --prefix)/bin/bash"
  else
    curl -s "https://get.sdkman.io" | bash
fi
sleep 3 # Required for the above command to be fully completed

echo "2. Selecting the Bash used to run SDKMAN..."
# SDKMAN's runtime uses Bash 4+ syntax (e.g. ${var^^}), which macOS's Bash 3.2
# cannot parse ("bad substitution"). So every `sdk` command below is run under
# the same modern Bash that installed SDKMAN. On Linux the system Bash already
# qualifies, so plain `bash` is used there.
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    sdkmanBash="$(brew --prefix)/bin/bash"
  else
    sdkmanBash="bash"
fi

echo "3. Verifying SDKMAN is usable..."
"$sdkmanBash" -c 'export SDKMAN_DIR="$HOME/.sdkman"; source "$HOME/.sdkman/bin/sdkman-init.sh"; sdk version'

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

# SDKMAN's runtime uses Bash 4+ syntax that macOS's Bash 3.2 cannot parse, so
# `sdk` runs under a modern Bash (Homebrew's on macOS; the system Bash on Linux).
# Resolved here so this procedure is runnable independently of the SDKMAN one:
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    sdkmanBash="$(brew --prefix)/bin/bash"
  else
    sdkmanBash="bash"
fi
"$sdkmanBash" -c '
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  echo "Installing Java 8..."
  # Java 8 Temurin release might be unavailable for macOS, so Zulu is installed:
  yes | sdk install java 8.0.492-zulu
  echo "Installing Java 11..."
  yes | sdk install java 11.0.31-tem
  echo "Installing Java 17..."
  yes | sdk install java 17.0.19-tem
  echo "Installing Java 21..."
  yes | sdk install java 21.0.11-tem
  echo "Installing Java 25 GraalVM..."
  yes | sdk install java 25.0.2-graalce
  echo "Installing Java 25..."
  yes | sdk install java 25.0.3-tem
  echo "Setting Java 25 as the default one..."
  sdk default java 25.0.3-tem
'

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

# SDKMAN's runtime uses Bash 4+ syntax that macOS's Bash 3.2 cannot parse, so
# `sdk` runs under a modern Bash (Homebrew's on macOS; the system Bash on Linux).
# Resolved here so this procedure is runnable independently of the SDKMAN one:
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    sdkmanBash="$(brew --prefix)/bin/bash"
  else
    sdkmanBash="bash"
fi
echo "Installing Maven..."
"$sdkmanBash" -c '
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  yes | sdk install maven 3.9.16
'

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

# SDKMAN's runtime uses Bash 4+ syntax that macOS's Bash 3.2 cannot parse, so
# `sdk` runs under a modern Bash (Homebrew's on macOS; the system Bash on Linux).
# Resolved here so this procedure is runnable independently of the SDKMAN one:
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    sdkmanBash="$(brew --prefix)/bin/bash"
  else
    sdkmanBash="bash"
fi
echo "Installing Spring Boot..."
"$sdkmanBash" -c '
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk install springboot
'

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
# argcomplete is required for pipx shell completion; brew's pipx (unlike apt's)
# does not pull it in automatically.
pipx install argcomplete
export PATH="$PATH:/Users/$(whoami)/.local/bin"
cat >> "$shellFile" << EOF

# PIPX AUTOCOMPLETION:
autoload -U +X bashcompinit && bashcompinit
eval "\$(register-python-argcomplete pipx)"
EOF

echo "Installing fzf (file finder)..."
brew install fzf

echo "Installing xclip (CLI-based clipboard selections)..."
brew install xclip

echo "Installing icdiff (tool for comparing files/directories)..."
brew install icdiff

echo "Installing jq (CLI JSON processor)..."
brew install jq

echo "Installing libxml2 (provides xmllint)..."
brew install libxml2

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

echo "Installing poppler (provides pdftotext for extracting text from PDFs)"
brew install poppler

echo "Installing mupdf-tools (provides mutool for PDF rendering and text extraction)"
brew install mupdf-tools

echo "Installing qpdf (PDF transformation, repair and inspection tool)"
brew install qpdf

echo "Installing pdfminer.six (Python PDF text extraction; provides pdf2txt.py and dumppdf.py)"
# PEP 668 blocks system-wide `pip3 install`, so use pipx (configured earlier in this block)
pipx install pdfminer.six

echo "Installing go (programming language)"
brew install go
# ADDING GO BINARIES TO PATH (so tools installed via `go install` are available):
cat >> "$shellFile" << EOF

# GO BINARIES ON PATH:
export PATH=\$PATH:\$(go env GOPATH)/bin
EOF

echo "Installing yt-dlp (YouTube downloader)..."
# 1. Do not perform installation via other package managers - the program might not work correctly then
# 2. Do not perform installation with sudo - it might not - the program might not work correctly then
# 3. Homebrew Python blocks `pip3 install` system-wide (PEP 668), so use pipx
pipx install yt-dlp

echo "Installing deno (JavaScript runtime required by yt-dlp)..."
# yt-dlp's YouTube extractor requires an external JavaScript runtime to solve
# challenges; without one it warns and some formats go missing. deno is the only
# runtime yt-dlp enables by default, so having it on PATH is enough - no yt-dlp
# config flags are needed. Docs: https://github.com/yt-dlp/yt-dlp/wiki/EJS
brew install deno
# Beyond a runtime, yt-dlp also needs the EJS challenge solver script, which it
# does not download unless opted in. `--remote-components ejs:github` (the
# upstream-recommended source) fetches the solver from yt-dlp's GitHub releases
# and runs it sandboxed under deno. Persist it in the yt-dlp config so YouTube
# extraction works without passing the flag each invocation.
mkdir -p "$HOME/.config/yt-dlp"
cat > "$HOME/.config/yt-dlp/config" << EOF
# Solve YouTube JS challenges via the EJS solver script (run under deno).
# See https://github.com/yt-dlp/yt-dlp/wiki/EJS
--remote-components ejs:github
EOF

echo "Installing postman (app for building and using APIs)..."
brew install postman

echo "installing node (server environment)..."
brew install node
# Point npm's global prefix at a stable, user-owned directory.
# Why: Homebrew installs npm with a version-pinned prefix
# (/opt/homebrew/Cellar/node/<version>), so every `brew upgrade node` orphans
# previously-installed global packages and leaves stale symlinks under
# /opt/homebrew/bin (e.g. a `tsc` whose underlying package is gone). A user-owned
# prefix also lets `npm install -g` run without sudo into a brew-owned tree.
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH" # so subsequent steps in this script find npm-installed CLIs
cat >> "$shellFile" << EOF

# ADDING NPM GLOBAL BINARIES TO PATH:
export PATH="\$HOME/.npm-global/bin:\$PATH"
EOF

echo "Installing TypeScript..."
# Installation docs:
#   bad: https://www.typescriptlang.org/download
#   good: https://lindevs.com/install-typescript-on-ubuntu
npm install -g typescript # `npm` comes from node, so node must be preinstalled

echo "Installing pnpm (Node.js package manager)..."
# Installation docs: https://pnpm.io/installation
# NOTES:
#   The pnpm standalone install script does NOT support Intel Macs
#   (darwin-x64). Homebrew is the officially recommended fallback on macOS
#   and works on both Apple Silicon and Intel.
brew install pnpm

echo "Installing Claude Code CLI (Anthropic's terminal-based AI coding agent)..."
# Installation docs: https://docs.claude.com/en/docs/claude-code/setup
# NOTES:
#   The native installer is the officially recommended method. It installs to
#   $HOME/.local/bin/claude and auto-updates in the background. The official
#   docs explicitly warn against `sudo npm install -g @anthropic-ai/claude-code`
#   due to permission issues and security risks.
curl -fsSL https://claude.ai/install.sh | bash

echo "Installing Mermaid CLI (diagramming tool)..."
npm install -g @mermaid-js/mermaid-cli

echo "Installing AIO CLI (Adobe CLI)..."
npm install -g @adobe/aio-cli

echo "Installing AIO CLI plugins..."
# Docs:
# https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/implementing/developing/rapid-development-environments#installing-the-rde-command-line-tools
aio plugins:install @adobe/aio-cli-plugin-aem-rde
aio plugins:update

echo "installing gpg (cryptography keys)..."
brew install gpg

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
iTermInstallationArchive="iTerm2-3_6_10.zip"

echo "1. Downloading the iTerm2 archive..."
# iterm2.com sits behind Cloudflare, which throttles wget's default 'Wget/...' User-Agent
# down to a few hundred B/s (browsers are unaffected). Present a browser User-Agent to
# avoid the throttling - otherwise the download crawls with an ETA of days.
wget --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" "https://iterm2.com/downloads/stable/$iTermInstallationArchive"

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

echo "1. Purging an existing vim/NeoVim setup if present..."
# Remove everything this procedure installs so it can be safely rerun from a clean
# state (mirrors the IntelliJ IDEA procedure).
nvimPids=$(pgrep -x nvim)
if [ -n "$nvimPids" ]; then
    kill $nvimPids
fi
if brew list neovim > /dev/null 2>&1; then
    brew uninstall neovim
fi
[ -e "$HOME/.vimrc" ]            && trash-put "$HOME/.vimrc"
[ -e "$HOME/.config/nvim" ]      && trash-put "$HOME/.config/nvim"
[ -e "$HOME/.config/nvim.bak" ]  && trash-put "$HOME/.config/nvim.bak"
[ -e "$HOME/.local/share/nvim" ] && trash-put "$HOME/.local/share/nvim"
[ -e "$HOME/.local/state/nvim" ] && trash-put "$HOME/.local/state/nvim"
[ -e "$HOME/.cache/nvim" ]       && trash-put "$HOME/.cache/nvim"

echo "2. Setting up vim as a default editor if this is Linux..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    sudo update-alternatives --set editor /usr/bin/vim.basic
fi

echo "3. Enabling cycling for {hjkl} vim keys if this is macOS..."
if [ "$isMacOS" == true ] && [ "$isLinux" == false ];
  then
    # Docs: https://stackoverflow.com/a/43340099
    defaults write -g ApplePressAndHoldEnabled -bool false
fi

echo "4. Updating .vimrc..."
vimrcFile="$HOME/.vimrc"
cat > "$vimrcFile" << EOF
" Sync the unnamed register with the system clipboard so y/p use it (https://stackoverflow.com/questions/27898407/intellij-idea-with-ideavim-cannot-copy-text-from-another-source):
" 'unnamed' is the '*' register (the macOS pasteboard); 'unnamedplus' is '+' (the Linux Ctrl+C clipboard). Listing both makes y/p hit the OS clipboard on either platform.
set clipboard=unnamed,unnamedplus

" Enable repeatable pasting in visual mode (https://stackoverflow.com/questions/7163947/paste-multiple-times):
xnoremap p pgvy

" Wrap lines:
set wrap
EOF

echo "5. Installing NeoVim..."
# 1. Do not install via snap, because it might cause problems like this:
#    https://github.com/LunarVim/LunarVim/issues/3612#issuecomment-1441131186
# 2. Do not install via apt, because it has an old version
brew install neovim

echo "6. Installing LazyVim..."
# LazyVim: https://www.lazyvim.org/
# The purge step above guarantees a clean ~/.config/nvim, so clone directly.
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

echo "7. Setting light LazyVim theme..."
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

echo "8. Opening an nvim application in order to initialize it..."
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    ptyxis -- bash -c "nvim test.lua -c 'startinsert'" # Need lua file to initiate LSP
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
# On Apple Script:
#   1. https://apple.stackexchange.com/a/335779
#   2. https://stackoverflow.com/questions/56862644/open-iterm2-from-bash-script-run-commands#comment105229692_56862822
# Always open nvim in a NEW iTerm window and target that window explicitly.
# Writing to "current session of current window" would type the command into the
# session running this script (whose stdin is then consumed by the `read` below),
# so nvim must run in its own dedicated window.
osascript -e '
tell application "iTerm"
    activate
    set nvimWindow to (create window with default profile)
    tell current session of nvimWindow
        write text "nvim test.lua"
    end tell
end tell'
  else
    echo "Unexpected error occurred. The requested action wasn't preformed correctly"
    exit 1
fi
echo "Once an nvim application is initialized, close it and press Enter to continue..."
read voidInput

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

echo "11. Suppressing noice.nvim popup notifications..."
# Filters out the floating error/notification popups (e.g. TextYankPost Lua errors)
# that noice.nvim renders in the top-right of the editor window.
noiceConfigFile="$HOME/.config/nvim/lua/plugins/noice.lua"
touch "$noiceConfigFile"
cat > "$noiceConfigFile" << EOF
return {
  {
    "folke/noice.nvim",
    opts = {
      routes = {
        { filter = { event = "msg_show", kind = "" }, opts = { skip = true } },
        { filter = { event = "notify", find = "TextYankPost" }, opts = { skip = true } },
      },
    },
  },
}
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
# `open -a AltTab` resolves the name via Launch Services, which has not registered
# the freshly-copied app yet, so open it by absolute path instead.
open "$HOME/Applications/AltTab.app"
sleep 5 # Give the application time to be initiated

printf "\n4. Give AltTab necessary permissions if requested. Press Enter when done...\n"
read voidInput

echo "5. Killing the AltTab application..."
killall AltTab
sleep 3 # Give the application time to be killed

echo "6. Configuring the AltTab application..."
# Export the freshly-installed domain, override only the keys we care about, then
# import it back so AltTab's own defaults are preserved. holdShortcut is stored as
# an NSKeyedArchiver dict { secureData = encoded key combo, string = display glyph };
# the secureData blob below is the archived "hold ⌘" shortcut.
altTabPlist="$tempDir/com.lwouis.alt-tab-macos.plist"
defaults export com.lwouis.alt-tab-macos "$altTabPlist"
# Hide the menu bar icon:
plutil -replace menubarIconShown -bool NO "$altTabPlist"
# Hold ⌘ (instead of the default ⌥) to summon AltTab:
plutil -replace holdShortcut -xml '<dict><key>secureData</key><data>YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGlCwwZGhtVJG51bGzWDQ4PEBESExQVFBcUXW1vZGlmaWVyRmxhZ3NfEBtjaGFyYWN0ZXJzSWdub3JpbmdNb2RpZmllcnNWJGNsYXNzWmNoYXJhY3RlcnNXa2V5Q29kZVd2ZXJzaW9ugAOAAIAEgACAAoAAEf//EgAQAADSHB0eH1okY2xhc3NuYW1lWCRjbGFzc2VzWlNSU2hvcnRjdXSiHiBYTlNPYmplY3QIERokKTI3SUxRU1lfbHqYn6qyury+wMLExsnO097n8vUAAAAAAAABAQAAAAAAAAAhAAAAAAAAAAAAAAAAAAAA/g==</data><key>string</key><string>⌘</string></dict>' "$altTabPlist"
# Ignore/hide certain apps (e.g. show iTerm2 only when it has standalone windows,
# not when it is running only as the dropdown panel):
altTabExceptions='[{"ignore":"0","bundleIdentifier":"com.apple.finder","hide":"2"},{"ignore":"2","bundleIdentifier":"com.apple.ScreenSharing","hide":"0"},{"ignore":"2","bundleIdentifier":"com.microsoft.rdc.macos","hide":"0"},{"ignore":"2","bundleIdentifier":"com.teamviewer.TeamViewer","hide":"0"},{"ignore":"2","bundleIdentifier":"org.virtualbox.app.VirtualBoxVM","hide":"0"},{"ignore":"2","bundleIdentifier":"com.parallels.","hide":"0"},{"ignore":"2","bundleIdentifier":"com.citrix.XenAppViewer","hide":"0"},{"ignore":"2","bundleIdentifier":"com.citrix.receiver.icaviewer.mac","hide":"0"},{"ignore":"2","bundleIdentifier":"com.nicesoftware.dcvviewer","hide":"0"},{"ignore":"2","bundleIdentifier":"com.vmware.fusion","hide":"0"},{"ignore":"2","bundleIdentifier":"com.utmapp.UTM","hide":"0"},{"ignore":"0","bundleIdentifier":"com.McAfee.McAfeeSafariHost","hide":"1"},{"ignore":"0","bundleIdentifier":"com.googlecode.iterm2","hide":"2"}]'
plutil -replace exceptions -string "$altTabExceptions" "$altTabPlist"
defaults import com.lwouis.alt-tab-macos "$altTabPlist"

echo "7. Opening the AltTab application..."
open "$HOME/Applications/AltTab.app"

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
# `open -a Tiles` resolves the name via Launch Services, which has not registered
# the freshly-copied app yet, so open it by absolute path instead.
tilesPath="$HOME/Applications/Tiles.app"
open "$tilesPath"

echo "4. Setting up the Tiles to launch on startup..."
# On login item adding: https://apple.stackexchange.com/a/310502
# On variables in the command below: https://stackoverflow.com/q/23923017
# The command below outputs 'login item UNKNOWN', which is ok: https://copyprogramming.com/howto/can-login-items-be-added-via-the-command-line-in-high-sierra?utm_content=cmp-true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$tilesPath"'", hidden:false}' > /dev/null

informAboutProcedureEnd

promptOnContinuation

###############################################################################
#                                                                             #
#                                                                             #
#                                14. FIREFOX                                  #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="firefox"
# DOCUMENTATION:
#   https://www.mozilla.org/firefox/
#   defaultbrowser CLI: https://github.com/kerma/defaultbrowser
#   duti CLI (sets file-type associations): https://github.com/moretension/duti
#   Firefox Sync: https://support.mozilla.org/kb/how-do-i-set-up-firefox-sync

informAboutProcedureStart

echo "1. Purging an existing Firefox setup if present..."
# Remove everything this procedure installs so it can be safely rerun from a clean
# state. The Firefox profile (~/Library/Application Support/Firefox) is left intact
# and restored via Sync in the last step; add `--zap` to the uninstall for a full wipe.
firefoxPids=$(pgrep -x firefox)
if [ -n "$firefoxPids" ]; then
    kill $firefoxPids
fi
if brew list --cask firefox > /dev/null 2>&1; then
    brew uninstall --cask firefox
fi
if brew list defaultbrowser > /dev/null 2>&1; then
    brew uninstall defaultbrowser
fi
if brew list duti > /dev/null 2>&1; then
    brew uninstall duti
fi

echo "2. Installing the Firefox application..."
brew install --cask firefox

echo "3. Installing defaultbrowser and duti CLIs (used to set the default browser and file associations headlessly)..."
brew install defaultbrowser
brew install duti

echo "4. Initiating Firefox so it registers as an HTTP/HTTPS handler with Launch Services..."
# `open -a Firefox` resolves the name via Launch Services, which has not registered
# the freshly-installed app yet, so open it by absolute path instead.
firefoxPath="/Applications/Firefox.app"
open "$firefoxPath"
sleep 7 # let the app register handlers

echo "5. Setting Firefox as the default browser..."
# `defaultbrowser firefox` flips the system handler. On modern macOS a confirmation
# dialog ("Use 'Firefox'") still pops up - it must be accepted manually in step 6.
defaultbrowser firefox

echo ""
echo "6. If a macOS dialog asks to confirm the default browser change, click 'Use Firefox'."
echo "   Press Enter when done..."
read voidInput

echo "7. Setting Firefox as the default viewer for PDF files..."
# `com.adobe.pdf` is the system UTI for PDF files; `all` covers every Launch Services
# role (viewer/editor). Without this, PDFs keep opening in Preview.
duti -s org.mozilla.firefox com.adobe.pdf all

printf "\n8. Log in to Firefox and enable Sync to restore bookmarks, history, passwords, extensions, and settings.\n"
echo "   Press Enter when done..."
read voidInput

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
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
#   https://github.com/cli/cli?tab=readme-ov-file#installation
#   Caching credentials for GitHub CLI: https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git
# NOTES:
#   On Linux, GitHub CLI is installed via the official apt repository rather than
#   Homebrew because Linuxbrew's bundled libcurl/openssl makes `gh repo clone`
#   extremely slow over HTTPS.

informAboutProcedureStart

if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    echo "1. Installing GitHub CLI..."
    (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
      && sudo mkdir -p -m 755 /etc/apt/keyrings \
      && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
      && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
      && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
      && sudo apt update \
      && sudo apt install gh -y
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

echo "Closing open System Settings panes in order to prevent them from overriding settings that will be changed now..."
osascript -e 'tell application "System Settings" to quit'

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
defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -int 0
# Ideally, also the following command should be executed, because without that property
# the "Reduce transparency" setting might not fully work. However, execution of that command
# within the script fails, but regardless of that failure the setting works as expected after
# the reboot: `defaults write com.apple.universalaccess reduceTransparency -int 1`

echo "Changing Appearance..."
defaults write "Apple Global Domain" AppleAquaColorVariant -int 6
defaults write "Apple Global Domain" AppleHighlightColor -string "0.847059 0.847059 0.862745 Graphite"
defaults write "Apple Global Domain" AppleAccentColor -string "-1"
defaults write "Apple Global Domain" AppleShowScrollBars -string Always

echo "Changing Control Center and menu bar..."
# The Control Center / menu bar layout (which items appear, their order, and the
# clock format) is stored as complex customization-state blobs that `defaults write`
# cannot set cleanly, so the captured plists are imported wholesale.
defaults import com.apple.controlcenter "$resourcesDir/mac/defaults/HOME/Library/Preferences/com.apple.controlcenter.plist"
defaults import com.apple.menuextra.clock "$resourcesDir/mac/defaults/HOME/Library/Preferences/com.apple.menuextra.clock.plist"
killall ControlCenter 2>/dev/null
killall SystemUIServer 2>/dev/null

echo "Changing Desktop & Dock..."
defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock mineffect scale
defaults write com.apple.dock "show-process-indicators" -int 0
defaults write com.apple.dock "show-recents" -int 0
defaults write com.apple.dock "mru-spaces" -int 0
defaults write com.apple.dock "wvous-br-corner" -int 1
defaults write com.apple.dock "wvous-br-modifier" -int 0
defaults write com.apple.WindowManager AutoHide -int 1
# Disable the margins macOS adds around tiled windows ("Window Margins" off)
defaults write com.apple.WindowManager EnableTiledWindowMargins -int 0
# Docs: https://apple.stackexchange.com/a/82084
defaults write com.apple.dock autohide-delay -float 1000; killall Dock

echo "Changing Spotlight..."
# macOS 26 stores Spotlight's per-source toggles in EnabledPreferenceRules (the legacy
# `orderedItems` array is no longer read). Counter-intuitively, a rule listed here is a
# source that is turned OFF; sources NOT listed (e.g. "Apps") stay ON. The list below is
# the captured "apps only" configuration - every non-app source is disabled. App-specific
# rules whose app is not installed are simply inert until that app is present.
defaults write com.apple.Spotlight EnabledPreferenceRules -array \
    "Custom.relatedContents" \
    "System.files" \
    "System.folders" \
    "System.iphoneApps" \
    "System.menuItems" \
    "com.apple.AppStore" \
    "com.apple.iBooksX" \
    "com.apple.calculator" \
    "com.apple.iCal" \
    "com.apple.AddressBook" \
    "com.apple.Dictionary" \
    "com.apple.mail" \
    "com.microsoft.Outlook" \
    "com.apple.Notes" \
    "com.microsoft.OneDrive" \
    "com.apple.Photos" \
    "com.apple.podcasts" \
    "com.apple.reminders" \
    "com.apple.Safari" \
    "com.apple.shortcuts" \
    "com.apple.systempreferences" \
    "com.apple.tips" \
    "com.apple.VoiceMemos"
killall Spotlight 2>/dev/null

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
# Disable all automatic text substitutions (Keyboard -> Text Input -> Edit...)
defaults write "Apple Global Domain" NSAutomaticCapitalizationEnabled -bool false
defaults write "Apple Global Domain" NSAutomaticSpellingCorrectionEnabled -bool false
defaults write "Apple Global Domain" NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write "Apple Global Domain" NSAutomaticDashSubstitutionEnabled -bool false
defaults write "Apple Global Domain" NSAutomaticPeriodSubstitutionEnabled -bool false
echo "Go to 'System Settings' -> 'Keyboard' and set preferrable input sources"
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
defaults write com.apple.finder CreateDesktop -bool false
# Use List view by default in Finder windows
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
killall Finder

echo ""
echo "Setting Touch ID..."
echo "Go to 'System Settings' -> 'Touch ID & Password' and set your Touch ID"
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
#                           19. DISPLAY BRIGHTNESS                            #
#                                                                             #
#                                                                             #
###############################################################################
procedureId="display brightness"
# DOCUMENTATION:
#   n/a
# NOTES:
#   These display settings are toggled manually. There is no reliable headless way to control
#   them on Apple Silicon: the `brightness` CLI fails with "failed to set brightness of display
#   ... (error -536870201)" and simulating the brightness-up key via `osascript ... key code
#   144` proved unreliable too (see https://stackoverflow.com/a/41915690).

informAboutProcedureStart

echo "Go to 'System Settings' -> 'Displays':"
echo "   Turn off 'Automatically adjust brightness'"
echo "   Turn off 'True Tone'"
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
if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
  then
    wget https://github.com/sayanarijit/xplr/releases/latest/download/xplr-linux.tar.gz
    tar --verbose --extract --file xplr-linux.tar.gz
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      wget https://github.com/sayanarijit/xplr/releases/latest/download/xplr-macos.tar.gz
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
xplrVersion=$(xplr --version | cut -d ' ' -f 2) # result like: X.Y.Z
xplrVersionAsConfigEntry="version = \"${xplrVersion:?}\"" # result like: version = "X.Y.Z"
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
    launcherPath="/snap/intellij-idea/current/bin/idea.sh"
  elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
    then
      jetbrainsConfigDir="$HOME/Library/Application Support/JetBrains"
      # Try Homebrew path first
      launcherPath="/opt/homebrew/bin/idea"
      # If Homebrew path is missing or a broken symlink, fallback to the Application bundle
      if [ ! -f "$launcherPath" ]; then
        launcherPath="/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"
      fi
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
    sudo snap remove intellij-idea
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
    sudo snap install intellij-idea --classic
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
echo "   5.6. If the 'Enable Embedded Browser' dialog appears, click 'Install Profile...'"
echo "        (installs the JCEF AppArmor profile; required since Ubuntu restricts unprivileged user namespaces)."
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

" Use the IDE's native paste for put operations (IdeaVim-only value; must NOT go in ~/.vimrc - plain Vim rejects it with E474):
set clipboard+=ideaput

" Make by default search case insensitive (https://stackoverflow.com/questions/2287440/how-to-do-case-insensitive-search-in-vim):
set ignorecase

" Disable error bells (https://stackoverflow.com/questions/11489428/how-to-make-vim-paste-from-and-copy-to-systems-clipboard):
set visualbell
set noerrorbells

" Highlight search results:
set hls

" Let the IDE handle Ctrl+W (otherwise IdeaVim swallows it as Vim's window-command prefix and IntelliJ's "Close Tab" shortcut never fires):
sethandler <C-w> a:ide

" Let the IDE handle Ctrl+B (otherwise IdeaVim swallows it as Vim's scroll-page-backward and IntelliJ's "Go to Declaration or Usages" shortcut never fires):
sethandler <C-b> a:ide

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
wget https://cdn.paint-x.com/cdnpaintx/dist/PaintX.dmg
sudo hdiutil attach PaintX.dmg
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

echo "Cloning and resolving ACS Commons repository..."
acsCommonsDir="$HOME/0_prog/acs-aem-commons"
mkdir -v -p "$acsCommonsDir"
if [ ! -d "$acsCommonsDir/.git" ]; then
    echo "Cloning an ACS Commons repository..."
    git clone https://github.com/Adobe-Consulting-Services/acs-aem-commons.git "$acsCommonsDir"
else
    echo "ACS Commons repository already exists. Skipping cloning."
fi
cd "$acsCommonsDir" || { echo "Failed to navigate to $acsCommonsDir. Exiting."; exit 1; }
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

echo "Cloning and building Sling Rocket repository..."
slingRocketDir="$HOME/0_prog/sling_rocket"
mkdir -v -p "$slingRocketDir"
if [ ! -d "$slingRocketDir/.git" ]; then
    echo "Cloning a Sling Rocket repository..."
    git clone https://github.com/ciechanowiec/sling_rocket.git "$slingRocketDir"
else
    echo "Sling Rocket repository already exists. Skipping cloning."
fi
cd "$slingRocketDir/src/2_rocket-instance/maven-project" || { echo "Failed to navigate to $slingRocketDir/src/2_rocket-instance/maven-project. Exiting."; exit 1; }
mvn clean install

echo "Cloning Payload CMS repository..."
payloadDir="$HOME/0_prog/payload"
mkdir -v -p "$payloadDir"
if [ ! -d "$payloadDir/.git" ]; then
    echo "Cloning a Payload CMS repository..."
    git clone https://github.com/payloadcms/payload.git "$payloadDir"
else
    echo "Payload CMS repository already exists. Skipping cloning."
fi

echo "Cloning proidc repository..."
proidcDir="$HOME/0_prog/proidc"
mkdir -v -p "$proidcDir"
if [ ! -d "$proidcDir/.git" ]; then
    echo "Cloning a proidc repository..."
    git clone https://github.com/ciechanowiec/proidc.git "$proidcDir"
else
    echo "proidc repository already exists. Skipping cloning."
fi

echo "Cloning slexamplus repository..."
slexamplusDir="$HOME/0_prog/slexamplus"
mkdir -v -p "$slexamplusDir"
if [ ! -d "$slexamplusDir/.git" ]; then
    echo "Cloning a slexamplus repository..."
    git clone https://github.com/ciechanowiec/slexamplus.git "$slexamplusDir"
else
    echo "slexamplus repository already exists. Skipping cloning."
fi

echo "Cloning Next.js repository..."
nextjsDir="$HOME/0_prog/next.js"
mkdir -v -p "$nextjsDir"
if [ ! -d "$nextjsDir/.git" ]; then
    echo "Cloning a Next.js repository..."
    git clone https://github.com/vercel/next.js.git "$nextjsDir"
else
    echo "Next.js repository already exists. Skipping cloning."
fi

echo "Cloning Node.js repository..."
nodejsDir="$HOME/0_prog/node"
mkdir -v -p "$nodejsDir"
if [ ! -d "$nodejsDir/.git" ]; then
    echo "Cloning a Node.js repository..."
    git clone https://github.com/nodejs/node.git "$nodejsDir"
else
    echo "Node.js repository already exists. Skipping cloning."
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
    # sling-whiteboard is an experimental sandbox repo; exclude it from cloning
    if [ "$repo_name" = "sling-whiteboard" ]; then
        echo "Skipping $repo_name (excluded)."
        continue
    fi
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
