#!/bin/bash

allImagesIDs=$(docker images --all --quiet)

if [ ${#allImagesIDs} == 0 ]
then
	echo "[INFO]: There are no Docker images to remove"
else
	echo "[INFO]: Removing Docker images..."
	docker rmi --force $allImagesIDs # Do not surround this variable with quote marks because then it might work incorrectly
fi
