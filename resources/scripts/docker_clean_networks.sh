#!/bin/bash

allNetworksNames=$(docker network ls --quiet)

if [ ${#allNetworksNames} == 0 ]
then
	echo "[INFO]: There are no Docker networks to remove"
else
	echo "[INFO]: Removing Docker networks..."
	docker network rm --force $allNetworksNames # Do not surround this variable with quote marks because then it might work incorrectly
fi
