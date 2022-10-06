#!/bin/bash

echo "Setting up variables..."
rootDir="$HOME/0_prog/0_aem_instances/aem-sdk"
formsDir="$rootDir/forms"
formsJAR="$formsDir/aem-quickstart-p4504.jar"
formsLicense="$formsDir/license.properties"

echo "Checking whether required directories and files exist..."
if [ ! -d "$rootDir" ] || [ ! -d "$formsDir" ] \
   || [ ! -f "$formsJAR" ] || [ ! -f "$formsLicense" ]
 then
   echo "At least one of required directories or files doesn't exist. Aborting..."
   exit 1
fi

echo "Starting the instance..."
cd "$formsDir" || exit 1
# This will run AEM in debug mode on 8889 port and also on usual 4504:
#   -Xdebug -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8890
# JVM specific params (https://experienceleague.adobe.com/docs/experience-manager-65/deploying/deploying/custom-standalone-install.html?lang=en):
#   -XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning
# Runmode params:
#   -Dsling.run.modes=publish,samplecontent,local,forms
java -Xdebug -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8890 \
-XX:+UseParallelGC --add-opens=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED --add-opens=java.naming/javax.naming.spi=ALL-UNNAMED --add-opens=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED -Dnashorn.args=--no-deprecation-warning \
-Dsling.run.modes=publish,samplecontent,local,forms \
-jar "$formsJAR"
