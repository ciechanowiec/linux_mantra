#!/usr/bin/env zsh
echo "==================================="
echo "|                                 |"
echo "|       DOCKER INSTALLATION       |"
echo "|                                 |"
echo "==================================="
echo "This script will install headless Docker and related software on your macOS"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script is intended to be run on macOS only"
  exit 1
fi

echo ""
echo "==========================="
echo "|  MACOS DEVELOPER TOOLS  |"
echo "==========================="
echo "Ensuring macOS developer tools, including git..."
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

echo ""
echo "==========================="
echo "|         HOMEBREW        |"
echo "==========================="
echo "Ensuring Homebrew..."
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
append_if_missing() {
  local snippet="$1"
  local marker="$2"  # A unique marker to search within the file
  if ! grep -Fq "$marker" "$ZSHRC"; then
    echo -e "$snippet" >> "$ZSHRC"
  fi
}
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [ -f "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
if command -v brew &>/dev/null; then
    echo "Homebrew is installed."
else
    echo "Installing Homebrew..."
    export NONINTERACTIVE=1
    sudo yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
echo "Ensuring the 'brew' command in the shell..."
if [ -f "/opt/homebrew/bin/brew" ]; then
    BREW_SHELLENV='eval "$(/opt/homebrew/bin/brew shellenv)"'
fi
if [ -f "/usr/local/bin/brew" ]; then
    BREW_SHELLENV='eval "$(/usr/local/bin/brew shellenv)"'
fi
BREW_SHELL_MARKER="# 'brew' command:"
append_if_missing "${BREW_SHELL_MARKER}" "${BREW_SHELLENV}"
append_if_missing "$BREW_SHELLENV" "$BREW_SHELLENV"
echo "Ensuring Homebrew autocompletion..."
read -r -d '' BREW_AUTOCOMPLETE <<'EOF'
# 'brew' autocompletion:
if type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    autoload -Uz compinit
    compinit
fi
EOF
BREW_AUTOCOMPLETE_MARKER="# 'brew' autocompletion:"
append_if_missing "$BREW_AUTOCOMPLETE" "$BREW_AUTOCOMPLETE_MARKER"
source "$ZSHRC"
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [ -f "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
brew --version

echo ""
echo "==========================="
echo "|          COLIMA         |"
echo "==========================="
echo "Ensuring Colima..."

if ! brew list --formula | grep -q '^colima$'; then
  echo "Installing Colima..."
  brew install colima --quiet
else
  echo "Colima is installed"
fi

if ! brew list --formula | grep -q '^qemu$'; then
  echo "Installing QEMU..."
  brew install qemu --quiet
else
  echo "QEMU is installed"
fi

SHARE_DIR="$HOME/.local/share"
SCRIPTS_DIR="$SHARE_DIR/colima-scripts"
SCRIPTS_LOGS_DIR="$SCRIPTS_DIR/logs"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENTS_DIR/la.abio.colima.plist"
COLIMA_LAUNCH_SCRIPT="$SCRIPTS_DIR/colima-start-fg.sh"
ERROR_LOG_FILE="$SCRIPTS_LOGS_DIR/startup.scripts.err"
OUT_LOG_FILE="$SCRIPTS_LOGS_DIR/startup.scripts.out"

if [ -f "/opt/homebrew/bin/brew" ]; then
    COLIMA_BIN_PATH="/opt/homebrew/bin/colima"
fi
if [ -f "/usr/local/bin/brew" ]; then
    COLIMA_BIN_PATH="/usr/local/bin/colima"
fi

if [ ! -d "$SHARE_DIR" ]
 then
   echo "Share directory doesn't exist. Creating $SHARE_DIR..."
   mkdir -p "$SHARE_DIR"
fi
if [ ! -d "$SCRIPTS_DIR" ]
 then
   echo "Scripts directory doesn't exist. Creating $SCRIPTS_DIR..."
   mkdir -p "$SCRIPTS_DIR"
fi
if [ ! -d "$SCRIPTS_LOGS_DIR" ]
 then
   echo "Scripts logs directory doesn't exist. Creating $SCRIPTS_LOGS_DIR..."
   mkdir -p "$SCRIPTS_LOGS_DIR"
fi
if [ ! -d "$LAUNCH_AGENTS_DIR" ]
 then
   echo "Launch agents directory doesn't exist. Creating $LAUNCH_AGENTS_DIR..."
   mkdir -p "$LAUNCH_AGENTS_DIR"
fi
touch "$ERROR_LOG_FILE"
touch "$OUT_LOG_FILE"

echo "Creating a startup launch agent: $LAUNCH_AGENT..."
cat > "$LAUNCH_AGENT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0">
 <dict>
   <key>Label</key>
   <string>la.abio.colima.plist</string>
   <key>Program</key>
   <string>$COLIMA_LAUNCH_SCRIPT</string>
   <key>RunAtLoad</key>
   <true/>
   <key>KeepAlive</key>
   <false/>
   <key>StandardErrorPath</key>
   <string>$ERROR_LOG_FILE</string>
   <key>StandardOutPath</key>
   <string>$OUT_LOG_FILE</string>
 </dict>
</plist>
EOF

echo "Creating a startup launch script: $COLIMA_LAUNCH_SCRIPT..."
cat > "$COLIMA_LAUNCH_SCRIPT" << EOF
#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "\$(/opt/homebrew/bin/brew shellenv)"
fi
if [ -f "/usr/local/bin/brew" ]; then
    eval "\$(/usr/local/bin/brew shellenv)"
fi

function shutdown() {
	$COLIMA_BIN_PATH stop
	exit 0
}

trap shutdown SIGTERM
trap shutdown SIGKILL
trap shutdown SIGINT

# wait until Colima is running
while true; do
	$COLIMA_BIN_PATH status &>/dev/null
	if [[ \$? -eq 0 ]]; then
		break
	fi
	$COLIMA_BIN_PATH start
	sleep 5
done

tail -f /dev/null &
wait \$!
EOF

echo "Making the startup launch script executable..."
sudo chmod +x "$COLIMA_LAUNCH_SCRIPT"

echo "Defining the Colima template file..."
COLIMA_TEMPLATES_DIR="$HOME/.colima/_templates"
COLIMA_TEMPLATE_DESTINATION_FILE="$COLIMA_TEMPLATES_DIR/default.yaml"
if [ ! -d "$COLIMA_TEMPLATES_DIR" ]
 then
   echo "Colima templates directory directory doesn't exist. Creating $COLIMA_TEMPLATES_DIR..."
   mkdir -p "$COLIMA_TEMPLATES_DIR"
fi
if [ -f "$COLIMA_TEMPLATE_DESTINATION_FILE" ]; then
  echo "\033[1mOld template file for Colima detected: $COLIMA_TEMPLATE_DESTINATION_FILE\033[0m"
  echo -n "Do you want to remove it (if you choose no, the script execution will stop)? [y/N] "
  read answer < /dev/tty
  case "$answer" in
    [Yy]* )
      rm -f "$COLIMA_TEMPLATE_DESTINATION_FILE"
      echo "File removed. Proceeding..."
      ;;
    * )
      echo "\033[1mPlease remove the file manually and run the script again.\033[0m"
      exit 1
      ;;
  esac
fi
echo "Writing: $COLIMA_TEMPLATE_DESTINATION_FILE..."
cat > "$COLIMA_TEMPLATE_DESTINATION_FILE" << EOF
# Number of CPUs to be allocated to the virtual machine.
# Default: 2
cpu: 4

# Size of the disk in GiB to be allocated to the virtual machine.
# NOTE: changing this has no effect after the virtual machine has been created.
# Default: 60
disk: 220

# Size of the memory in GiB to be allocated to the virtual machine.
# Default: 2
memory: 16

# Architecture of the virtual machine (x86_64, aarch64, host).
# Default: host
arch: host

# Container runtime to be used (docker, containerd).
# Default: docker
runtime: docker

# Kubernetes configuration for the virtual machine.
kubernetes:
  # Enable kubernetes.
  # Default: false
  enabled: false

  # Kubernetes version to use.
  # This needs to exactly match a k3s version https://github.com/k3s-io/k3s/releases
  # Default: latest stable release
  version: v1.24.3+k3s1

  # Disable k3s features [coredns servicelb traefik local-storage metrics-server].
  # All features are enabled unless disabled.
  #
  # EXAMPLE - disable traefik and metrics-server
  # disable: [traefik, metrics-server]
  #
  # Default: [traefik]
  disable:
    - traefik

# Auto-activate on the Host for client access.
# Setting to true does the following on startup
#  - sets as active Docker context (for Docker runtime).
#  - sets as active Kubernetes context (if Kubernetes is enabled).
# Default: true
autoActivate: true

# Network configurations for the virtual machine.
network:
  # Assign reachable IP address to the virtual machine.
  # NOTE: this is currently macOS only and ignored on Linux.
  # Default: false
  address: true

  # Custom DNS resolvers for the virtual machine.
  #
  # EXAMPLE
  # dns: [8.8.8.8, 1.1.1.1]
  #
  # Default: []
  dns: []

  # DNS hostnames to resolve to custom targets using the internal resolver.
  # This setting has no effect if a custom DNS resolver list is supplied above.
  # It does not configure the /etc/hosts files of any machine or container.
  # The value can be an IP address or another host.
  #
  # EXAMPLE
  # dnsHosts:
  #   example.com: 1.2.3.4
  dnsHosts:
    host.docker.internal: host.lima.internal

  # Network driver to use (slirp, gvproxy), (requires vmType \`qemu\`)
  #   - slirp is the default user mode networking provided by Qemu
  #   - gvproxy is an alternative to VPNKit based on gVisor https://github.com/containers/gvisor-tap-vsock
  # Default: gvproxy
  driver: gvproxy

# ===================================================================== #
# ADVANCED CONFIGURATION
# ===================================================================== #

# Forward the host's SSH agent to the virtual machine.
# Default: false
forwardAgent: false

# Docker daemon configuration that maps directly to daemon.json.
# https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file.
# NOTE: some settings may affect Colima's ability to start docker. e.g. \`hosts\`.
#
# EXAMPLE - disable buildkit
# docker:
#   features:
#     buildkit: false
#
# EXAMPLE - add insecure registries
# docker:
#   insecure-registries:
#     - myregistry.com:5000
#     - host.docker.internal:5000
#
# Colima default behaviour: buildkit enabled
# Default: {}
docker: {}

# Virtual Machine type (qemu, vz)
# NOTE: this is macOS 13 only. For Linux and macOS <13.0, qemu is always used.
#
# vz is macOS virtualization framework and requires macOS 13
#
# Default: qemu
vmType: qemu

# Utilise rosetta for amd64 emulation (requires m1 mac and vmType \`vz\`)
# Default: false
rosetta: false

# Volume mount driver for the virtual machine (virtiofs, 9p, sshfs).
#
# virtiofs is limited to macOS and vmType \`vz\`. It is the fastest of the options.
#
# 9p is the recommended and the most stable option for vmType \`qemu\`.
#
# sshfs is faster than 9p but the least reliable of the options (when there are lots
# of concurrent reads or writes).
#
# Default: virtiofs (for vz), sshfs (for qemu)
mountType: sshfs

# The CPU type for the virtual machine (requires vmType \`qemu\`).
# Options available for host emulation can be checked with: \`qemu-system-\$(arch) -cpu help\`.
# Instructions are also supported by appending to the cpu type e.g. "qemu64,+ssse3".
# Default: host
cpuType: host

# For a more general purpose virtual machine, Ubuntu container is optionally provided
# as a layer on the virtual machine.
# The underlying virtual machine is still accessible via \`colima ssh --layer=false\` or running \`colima\` in
# the Ubuntu session.
#
# Default: false
layer: false

# Custom provision scripts for the virtual machine.
# Provisioning scripts are executed on startup and therefore needs to be idempotent.
#
# EXAMPLE - script exected as root
# provision:
#   - mode: system
#     script: apk add htop vim
#
# EXAMPLE - script exected as user
# provision:
#   - mode: user
#     script: |
#       [ -f ~/.provision ] && exit 0;
#       echo provisioning as \$USER...
#       touch ~/.provision
#
# Default: []
provision: []

# Modify ~/.ssh/config automatically to include a SSH config for the virtual machine.
# SSH config will still be generated in ~/.colima/ssh_config regardless.
# Default: true
sshConfig: true

# Configure volume mounts for the virtual machine.
# Colima mounts user's home directory by default to provide a familiar
# user experience.
#
# EXAMPLE
# mounts:
#   - location: ~/secrets
#     writable: false
#   - location: ~/projects
#     writable: true
#
# Colima default behaviour: \$HOME and /tmp/colima are mounted as writable.
# Default: []
mounts: []

# Environment variables for the virtual machine.
#
# EXAMPLE
# env:
#   KEY: value
#   ANOTHER_KEY: another value
#
# Default: {}
env: {}
EOF

echo ""
echo "==========================="
echo "|          DOCKER         |"
echo "==========================="
echo "Ensuring Docker..."

if ! brew list --formula | grep -q '^docker$'; then
  echo "Installing Docker brew..."
  brew install docker --quiet
else
  echo "Docker brew is installed"
fi

if ! brew list --formula | grep -q '^docker-compose$'; then
  echo "Installing Docker Compose brew..."
  brew install docker-compose --quiet
else
  echo "Docker Compose brew is installed"
fi
echo "Attempting to stop Colima..."
colima stop
echo "Attempting to start Colima..."
colima start
echo "Will run sample docker container to verify the installation..."
docker run hello-world

if [[ $? -ne 0 ]]; then
  echo -e "\033[31mDocker installation failed\033[0m"
  echo -n "Proceed with the script anyway? [y/N] "
  read answer < /dev/tty
  case "$answer" in
    [Yy]* )
      echo "Proceeding..."
      ;;
    * )
      echo "Exiting..."
      exit 1
      ;;
  esac
fi

echo ""
echo "==========================="
echo "|    DOCKER VARIABLES     |"
echo "==========================="
echo "Ensuring Docker Variables..."
DOCKER_VARIABLES_MARKER="# MAKE DOCKER CLIENTS SEE THE CUSTOM SOCKET:"
if ! grep -Fq "$DOCKER_VARIABLES_MARKER" "$HOME/.zshrc"; then
  echo "Adding Docker variables to $HOME/.zshrc..."
  cat >> "$HOME/.zshrc" << EOF

$DOCKER_VARIABLES_MARKER
export DOCKER_HOST=unix:///Users/$(whoami)/.colima/default/docker.sock
# FIX TESTCONTAINERS (https://github.com/testcontainers/testcontainers-java/issues/7082):
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="/var/run/docker.sock"
export TESTCONTAINERS_HOST_OVERRIDE="\$(colima ls -j | jq -r '.address')"
EOF
fi
echo "Done"

echo ""
echo "==========================="
echo "|     DOCKER BUILDX       |"
echo "==========================="
echo "Ensuring Docker Builx..."
if [ -f "$HOME/.docker/cli-plugins/docker-buildx" ]; then
    echo "Docker Buildx already installed at ~/.docker/cli-plugins/docker-buildx. Skipping installation."
else
  os=$(uname | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
      x86_64) arch="amd64" ;;
      arm64|aarch64) arch="arm64" ;;
      *) echo "Unsupported architecture: $arch"; exit 1 ;;
  esac
  releaseFileSuffix="${os}-${arch}"
  echo "Detected platform suffix: $releaseFileSuffix"
  temp_dir=$(mktemp -d)
  echo "Using temporary directory: $temp_dir"
  pushd "$temp_dir" > /dev/null || { echo "Failed to change directory to $temp_dir"; exit 1; }
  BUILDX_API_URL="https://api.github.com/repos/docker/buildx/releases/latest"
  echo "Querying GitHub API for the latest release..."
  asset_url=$(curl -s "$BUILDX_API_URL" | \
              grep "browser_download_url.*\\.${releaseFileSuffix}\"" | \
              head -n 1 | \
              cut -d '"' -f 4)
  if [ -z "$asset_url" ]; then
      echo "No asset found for suffix $releaseFileSuffix"
      popd > /dev/null || { echo "Failed to return from directory $temp_dir"; exit 1; }
      rm -rf "$temp_dir"
      exit 1
  else
      filename=$(basename "$asset_url")
      echo "Downloading $filename from $asset_url..."
      curl --verbose --location --output "$filename" "$asset_url"
      mkdir -v -p "$HOME/.docker/cli-plugins"
      mv -v -f "$filename" "$HOME/.docker/cli-plugins/docker-buildx"
      chmod +x "$HOME/.docker/cli-plugins/docker-buildx"
      popd > /dev/null || { echo "Failed to return from directory $temp_dir"; exit 1; }
      rm -rf "$temp_dir"
  fi
fi

echo "Docker Buildx version installed:"
docker buildx version

echo ""
echo "==========================="
echo "|         RESTART         |"
echo "==========================="
echo "Installation finished"
echo "Restart your computer for changes to come info force..."
