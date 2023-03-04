#!/bin/bash

allVolumesNames=$(docker volume ls --quiet)

if [ ${#allVolumesNames} == 0 ]
then
	echo "[INFO]: There are no Docker volumes to remove"
else
	echo "[INFO]: Removing Docker volumes..."
	docker volume rm --force $allVolumesNames # Do not surround this variable with quote marks because then it might work incorrectly
fi
