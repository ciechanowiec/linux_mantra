#!/bin/bash

# Docs: https://stackoverflow.com/a/71265260

BOLD_RED="\e[1;91m"
RESET_FORMAT="\e[0m"
ERROR_TAG="${BOLD_RED}[ERROR]:${RESET_FORMAT}"

verifyIfExactlyTwoArgs () {
	if [ $# != 2 ]
	then
    printf "${ERROR_TAG} The command must be provided with exactly two arguments: a VM path and a destination path. Execution has been aborted.\n"
		exit
	fi
}

verifyIfExactlyTwoArgs "$@"
vmPath="$1"
destinationPath="$2"

tmpconfig=$(mktemp)
(cat "$HOME/.colima/ssh_config" | grep --invert-match "^  ControlPath\|  ^User"; echo "  ForwardAgent=yes") > "$tmpconfig"
ssh -F "$tmpconfig" "$USER@colima" "sudo mkdir -p /root/.ssh/; sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys"

ssh -F "$tmpconfig" root@colima "[ -e $vmPath ]"
exitCode=$?
if [ "$exitCode" != 0 ]
  then
    printf "${ERROR_TAG} VM path wasn't found: $vmPath. Execution has been aborted.\n"
    exit 1
fi

scp -F "$tmpconfig" root@colima:"$vmPath" "$destinationPath"
