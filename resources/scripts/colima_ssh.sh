#!/bin/bash

# Docs: https://stackoverflow.com/a/71265260

tmpconfig=$(mktemp)
(cat "$HOME/.colima/ssh_config" | grep --invert-match "^  ControlPath\|  ^User"; echo "  ForwardAgent=yes") > "$tmpconfig"
ssh -F "$tmpconfig" "$USER@colima" "sudo mkdir -p /root/.ssh/; sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys"
ssh -F "$tmpconfig" root@colima
