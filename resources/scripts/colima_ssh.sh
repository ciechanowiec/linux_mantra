#!/bin/bash

# Docs: https://stackoverflow.com/a/71265260

tmpconfig=$(mktemp)
(grep --invert-match "^  ControlPath\|^  User" "${HOME}/.colima/ssh_config"; echo "  ForwardAgent=yes") > "${tmpconfig}"
ssh -F "${tmpconfig}" "${USER}@colima" "sudo mkdir -p /root/.ssh/; sudo cp ~/.ssh/authorized_keys /root/.ssh/authorized_keys"
ssh -F "${tmpconfig}" root@colima
