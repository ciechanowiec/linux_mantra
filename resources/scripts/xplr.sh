#!/bin/bash

if [ "$#" -eq 0 ]
  then
    xplr "$HOME"
  else
    xplr "$@"
fi
