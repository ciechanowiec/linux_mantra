#!/bin/bash

aptUpdateConfigFile="/etc/apt/apt.conf.d/20auto-upgrades"

sudo bash -c "cat > ${aptUpdateConfigFile} << EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "1";
EOF
"
