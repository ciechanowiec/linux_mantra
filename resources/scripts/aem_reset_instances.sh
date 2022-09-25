#!/bin/bash

# Deployment folders structure
#  aem-sdk
#  ├───author
#  │   ├───aem-author-p4502.jar
#  │   └───license.properties
#  ├───publish
#  │   ├───aem-publish-p4503.jar
#  │   └───license.properties
#  ├───adobe-aemfd-linux-pkg-6.0.334.zip
#  ├───aem-service-pkg-6.5.14.0.zip
#  ├───basicContent.zip
#  ├───formsContent.zip
#  └───testContent.zip

echo "Setting up variables..."
# Current directory
currentDir=$(pwd)
# Root directory
rootDir="$HOME/0_prog/0_aem_instances/aem-sdk"
# Initial packages
formsPackage="$rootDir/adobe-aemfd-linux-pkg-6.0.334.zip"
servicePackage="$rootDir/aem-service-pkg-6.5.14.0.zip"
basicContent="$rootDir/basicContent.zip"
formsContent="$rootDir/formsContent.zip"
testContent="$rootDir/testContent.zip"
# Author/Publish directories
authorDir="$rootDir/author"
publishDir="$rootDir/publish"
# AEM JARs
authorJAR="$authorDir/aem-author-p4502.jar"
publishJAR="$publishDir/aem-publish-p4503.jar"
# JCR paths
authorJCR="$authorDir/crx-quickstart"
publishJCR="$publishDir/crx-quickstart"
# sling.properties on AEM Author
slingPropsOfAuthor="$authorDir/crx-quickstart/conf/sling.properties"
# Initial installation directories
authorInstallDir="$authorJCR/install"
publishInstallDir="$publishJCR/install"

echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] || [ ! -f "$formsPackage" ] || [ ! -f "$servicePackage" ] \
   || [ ! -f "$basicContent" ] || [ ! -f "$formsContent" ] || [ ! -f "$testContent" ] \
   || [ ! -d "$authorDir" ] || [ ! -d "$publishDir" ] \
   || [ ! -f "$authorJAR" ] || [ ! -f "$publishJAR" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

echo "Resetting AEM Author instance..."
cd "$authorDir" || exit 1
if [ -d "$authorJCR" ]
  then
    rm -rf "$authorJCR"
fi
java -jar "$authorJAR" -unpack
mkdir "$authorInstallDir"
cp "$servicePackage" "$authorInstallDir"
cp "$formsPackage" "$authorInstallDir"
cp "$basicContent" "$authorInstallDir"
cp "$formsContent" "$authorInstallDir"
cp "$testContent" "$authorInstallDir"
cd "$currentDir" || exit 1

echo "Setting up AEM Forms bootstrap properties..."
# 1. Two following lines should be added to $slingPropsOfAuthor for AEM Forms to work:
#      sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
#      sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
# 2. Be aware that in order for 'AEMFD Signatures Bundle (adobe-aemfd-signatures)' from AEM Forms to start,
#    AEM should be restarted after the first start.
cat >> "$slingPropsOfAuthor" << EOF
sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
EOF

echo "Resetting AEM Publish instance..."
# In this particular case $formsPackage and $formsContent aren't supposed to be installed on AEM Publish
cd "$publishDir" || exit 1
if [ -d "$publishJCR" ]
  then
    rm -rf "$publishJCR"
fi
java -jar "$publishJAR" -unpack
mkdir "$publishInstallDir"
cp "$servicePackage" "$publishInstallDir"
cp "$basicContent" "$publishInstallDir"
cp "$testContent" "$publishInstallDir"
cd "$currentDir" || exit 1
