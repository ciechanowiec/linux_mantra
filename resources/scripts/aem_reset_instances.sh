#!/bin/bash

# Deployment folders structure
#  aem-sdk
#  ├───author
#  │   ├───aem-quickstart-p4502.jar
#  │   └───license.properties
#  ├───forms
#  │   ├───aem-quickstart-p4504.jar
#  │   └───license.properties
#  ├───publish
#  │   ├───aem-quickstart-p4503.jar
#  │   └───license.properties
#  ├───adobe-aemfd-linux-pkg-6.0.334.zip
#  ├───aem-service-pkg-6.5.14.0.zip
#  ├───basicContent.zip
#  ├───formsContent.zip
#  └───testContent.zip

# ============================================== #
#                   VARIABLES                    #
# ============================================== #
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
# Instance directories
authorDir="$rootDir/author"
formsDir="$rootDir/forms"
publishDir="$rootDir/publish"
# AEM JARs
authorJAR="$authorDir/aem-quickstart-p4502.jar"
formsJAR="$formsDir/aem-quickstart-p4504.jar"
publishJAR="$publishDir/aem-quickstart-p4503.jar"
# Licenses
authorLicense="$authorDir/license.properties"
formsLicense="$formsDir/license.properties"
publishLicense="$publishDir/license.properties"
# JCR paths
authorJCR="$authorDir/crx-quickstart"
formsJCR="$formsDir/crx-quickstart"
publishJCR="$publishDir/crx-quickstart"
# sling.properties on AEM Author and AEM Forms
authorSlingProps="$authorDir/crx-quickstart/conf/sling.properties"
formsSlingProps="$formsDir/crx-quickstart/conf/sling.properties"
# Initial installation directories
authorInstallDir="$authorJCR/install"
formsInstallDir="$formsJCR/install"
publishInstallDir="$publishJCR/install"

# ============================================== #
#                     CHECKS                     #
# ============================================== #
echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] \
   || [ ! -f "$formsPackage" ] || [ ! -f "$servicePackage" ] || [ ! -f "$basicContent" ] || [ ! -f "$formsContent" ] || [ ! -f "$testContent" ] \
   || [ ! -d "$authorDir" ] || [ ! -d "$formsDir" ] || [ ! -d "$publishDir" ] \
   || [ ! -f "$authorJAR" ] || [ ! -f "$formsJAR" ] || [ ! -f "$publishJAR" ] \
   || [ ! -f "$authorLicense" ] || [ ! -f "$formsLicense" ]  || [ ! -f "$publishLicense" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

# ============================================== #
#                   AEM AUTHOR                   #
# ============================================== #
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
# Two following lines should be added to $authorSlingProps for AEM Forms to work:
#   sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
#   sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
cat >> "$authorSlingProps" << EOF
sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
EOF

# ============================================== #
#                    AEM FORMS                   #
# ============================================== #
echo "Resetting AEM Forms instance..."
cd "$formsDir" || exit 1
if [ -d "$formsJCR" ]
  then
    rm -rf "$formsJCR"
fi
java -jar "$formsJAR" -unpack
mkdir "$formsInstallDir"
cp "$servicePackage" "$formsInstallDir"
cp "$formsPackage" "$formsInstallDir"
cp "$basicContent" "$formsInstallDir"
cp "$formsContent" "$formsInstallDir"
cp "$testContent" "$formsInstallDir"
cd "$currentDir" || exit 1

echo "Setting up AEM Forms bootstrap properties..."
# Two following lines should be added to $formsSlingProps for AEM Forms to work:
#   sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
#   sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
cat >> "$formsSlingProps" << EOF
sling.bootdelegation.class.org.bouncycastle.jce.provider.BouncyCastleProvider=org.bouncycastle.*
sling.bootdelegation.class.com.rsa.jsafe.provider.JsafeJCE=com.rsa.*
EOF

# ============================================== #
#                  AEM PUBLISH                   #
# ============================================== #
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
