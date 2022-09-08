#!/bin/bash

# Deployment folders structure
#   aem-sdk
#    ├── author
#    │   ├── crx-quickstart
#    │   ├── aem-author-p4502.jar
#    │   └── license.properties
#    └── publish
#        ├── crx-quickstart
#        ├── aem-publish-p4503.jar
#        └── license.properties

echo "Setting up variables..."
# Current directory
currentDir=$(pwd)
# Root directory
rootDir="$HOME/0_prog/0_aem_instances/aem-sdk"
# Initial packages
servicePackage="$rootDir/aem-service-pkg-6.5.14.0.zip"
basicContent="$rootDir/basicContent.zip"
testContent="$rootDir/testContent.zip"
# Author/Publish directories
authorDir="$rootDir/author"
publishDir="$rootDir/publish"
# AEM JARs
authorJAR="$authorDir/aem-author-p4502.jar"
publishJAR="$publishDir/aem-publish-p4503.jar"
# JCR Paths
authorJCR="$authorDir/crx-quickstart"
publishJCR="$publishDir/crx-quickstart"
# Initial installation directories
authorInstallDir="$authorJCR/install"
publishInstallDir="$publishJCR/install"

echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] || [ ! -f "$servicePackage" ] \
   || [ ! -f "$basicContent" ] || [ ! -f "$testContent" ] \
   || [ ! -d "$authorDir" ] || [ ! -d "$publishDir" ] \
   || [ ! -f "$authorJAR" ] || [ ! -f "$publishJAR" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

echo "Resetting an author AEM instance..."
cd "$authorDir" || exit 1
if [ -d "$authorJCR" ]
  then
    trash-put "$authorJCR"
fi
java -jar "$authorJAR" -unpack
mkdir "$authorInstallDir"
cp "$servicePackage" "$authorInstallDir"
cp "$basicContent" "$authorInstallDir"
cp "$testContent" "$authorInstallDir"
cd "$currentDir" || exit 1

echo "Resetting a publish AEM instance..."
cd "$publishDir" || exit 1
if [ -d "$publishJCR" ]
  then
    trash-put "$publishJCR"
fi
java -jar "$publishJAR" -unpack
mkdir "$publishInstallDir"
cp "$servicePackage" "$publishInstallDir"
cp "$basicContent" "$publishInstallDir"
cp "$testContent" "$publishInstallDir"
cd "$currentDir" || exit 1
