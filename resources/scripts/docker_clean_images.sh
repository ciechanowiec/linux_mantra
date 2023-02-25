#!/bin/bash

allImagesIDs=$(sudo docker images -aq)

if [ ${#allImagesIDs} == 0 ]
then
	echo "[INFO]: There are no Docker images to remove"
else
	echo "[INFO]: Removing Docker images..."
	sudo docker rmi -f $allImagesIDs # Do not surround this variable with quote marks because then it might work incorrectly
fi
