#!/bin/bash

echo "Setting up variables..."
rootDir="$HOME/0_prog/0_aem_instances/aem-sdk"
authorDir="$rootDir/author"
authorJAR="$authorDir/aem-author-p4502.jar"

echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] || [ ! -d "$authorDir" ] || [ ! -f "$authorJAR" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

echo "Starting instance..."
cd "$authorDir" || exit 1
# This will run AEM in debug mode on 8888 port and also on usual 4502:
java -Xdebug -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8888 -jar "$authorJAR"
