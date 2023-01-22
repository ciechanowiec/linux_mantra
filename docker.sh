#!/bin/bash

#Uninstallation from https://docs.docker.com/engine/install/ubuntu/

#For a complete cleanup, remove configuration and data files at $HOME/.docker/desktop, the symlink at /usr/local/bin/com.docker.cli, and purge the remaining systemd service files:
rm -r $HOME/.docker/desktop
sudo rm /usr/local/bin/com.docker.cli
sudo apt remove docker-desktop -y

#Uninstallation from https://docs.docker.com/desktop/install/ubuntu/

#Older versions of Docker went by the names of docker, docker.io, or docker-engine. Uninstall any such older versions before attempting to install a new version:
sudo apt remove docker docker-engine docker.io containerd runc -y

#Uninstall the Docker Engine, CLI, containerd, and Docker Compose packages:
sudo apt remove docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras -y

#Images, containers, volumes, or custom configuration files on your host aren’t automatically removed. To delete all images, containers, and volumes:
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

#Uninstallation from myself
sudo snap remove docker
