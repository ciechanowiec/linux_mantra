#!/bin/bash

# 1. The archetype below works on AEM 6.5.14.
#    However, as of creating this script (2022-08-27), no `uber-jar` of the
#    version 6.5.14 was available. For that reason aemVersion was set to 6.5.13.
# 2. As of creating this script, if for project generation Java 11+ is used, it will result
#    in unformatted `/pom.xml` (see bug description: https://issues.apache.org/jira/browse/ARCHETYPE-587).
#    In order to avoid it, Java 8 is used.
# 3. Use -SNAPSHOT version so that the bundle will be overwritten every time it is reinstalled (details: https://sling.apache.org/documentation/bundles/osgi-installer.html#:~:text=The%20OSGi%20installer%20is%20a,for%20the%20OSGi%20configuration%20admin)

source "$HOME/.sdkman/bin/sdkman-init.sh" # To make sdk command work

sdk use java 8.0.345-tem

mvn -B org.apache.maven.plugins:maven-archetype-plugin:3.2.1:generate \
    -D archetypeGroupId=com.adobe.aem \
    -D archetypeArtifactId=aem-project-archetype \
    -D archetypeVersion=39 \
    -D appTitle="First Hops" \
    -D appId="firsthops" \
    -D groupId="eu.ciechanowiec" \
    -D artifactId="firsthops" \
    -D package="eu.ciechanowiec.firsthops" \
    -D includeExamples=y \
    -D version="1.0-SNAPSHOT" \
    -D aemVersion="6.5.13"

sdk use java 11.0.16-tem
