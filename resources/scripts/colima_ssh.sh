#!/bin/bash

# Docs: https://stackoverflow.com/a/71265260

tmpconfig=$(mktemp)
(limactl show-ssh --format config colima | grep --invert-match "^  ControlPath\|  ^User"; echo "  ForwardAgent=yes") > "$tmpconfig"
ssh -F "$tmpconfig" "$USER@lima-colima" "sudo mkdir -p /root/.ssh/; sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys"
ssh -F "$tmpconfig" root@lima-colima
