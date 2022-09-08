#!/bin/bash

echo "Setting up variables..."
rootDir="$HOME/0_prog/0_aem_instances/aem-sdk"
publishDir="$rootDir/publish"
publishJAR="$publishDir/aem-publish-p4503.jar"

echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] || [ ! -d "$publishDir" ] || [ ! -f "$publishJAR" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

echo "Starting instance..."
cd "$publishDir" || exit 1
# This will run AEM in debug mode on 8888 port and also on usual 4503:
java -Xdebug -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8889 -jar "$publishJAR"

