#!/bin/bash

allContainersIDs=$(docker ps --all --quiet)

if [ ${#allContainersIDs} == 0 ]
then
	echo "[INFO]: There are no Docker containers to remove"
else
	echo "[INFO]: Removing Docker containers..."
	docker rm --force --volumes $allContainersIDs # Do not surround this variable with quote marks because then it might work incorrectly
fi
