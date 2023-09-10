#!/bin/bash

# Docs: https://stackoverflow.com/a/71265260

BOLD_RED="\e[1;91m"
RESET_FORMAT="\e[0m"
ERROR_TAG="${BOLD_RED}[ERROR]:${RESET_FORMAT}"

verifyIfExactlyTwoArgs () {
	if [ $# != 2 ]
	then
    printf "${ERROR_TAG} The command must be provided with exactly two arguments: a host path and a destination path. Execution has been aborted.\n"
		exit
	fi
}

verifyIfExactlyTwoArgs "$@"
hostPath="$1"
destinationPath="$2"

tmpconfig=$(mktemp)
(limactl show-ssh --format config colima | grep --invert-match "^  ControlPath\|  ^User"; echo "  ForwardAgent=yes") > "$tmpconfig"
ssh -F "$tmpconfig" "$USER@lima-colima" "sudo mkdir -p /root/.ssh/; sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys"
ssh -F "$tmpconfig" root@lima-colima "mkdir -p $destinationPath"
scp -F "$tmpconfig" "$hostPath" root@lima-colima:"$destinationPath"
