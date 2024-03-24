#!/bin/bash

"$HOME/scripts/docker_clean_containers.sh"
"$HOME/scripts/docker_clean_images.sh"
"$HOME/scripts/docker_clean_volumes.sh"
"$HOME/scripts/docker_clean_networks.sh"
docker system prune --all --force
