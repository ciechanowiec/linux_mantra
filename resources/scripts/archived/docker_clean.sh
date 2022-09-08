#!/bin/bash

allContainersIDs=$(sudo docker ps -aq)
allImagesIDs=$(sudo docker images -aq)

if [ ${#allContainersIDs} == 0 ]
then
	echo "[INFO]: There are no Docker containers to remove"
else
	echo "[INFO]: Removing Docker containers..."
	sudo docker rm -vf $allContainersIDs
fi

if [ ${#allImagesIDs} == 0 ]
then
	echo "[INFO]: There are no Docker images to remove"
else
	echo "[INFO]: Removing Docker images..."
	sudo docker rmi -f $allImagesIDs
fi
