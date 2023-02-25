#!/bin/bash

allContainersIDs=$(sudo docker ps -aq)

if [ ${#allContainersIDs} == 0 ]
then
	echo "[INFO]: There are no Docker containers to remove"
else
	echo "[INFO]: Removing Docker containers..."
	sudo docker rm -vf $allContainersIDs # Do not surround this variable with quote marks because then it might work incorrectly
fi
