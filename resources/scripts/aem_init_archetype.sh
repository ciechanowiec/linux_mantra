#!/bin/bash

# 1. The archetype below works on AEM 6.5.14.
#    However, as of creating this script (2022-08-27), no `uber-jar` of the
#    version 6.5.14 was available. For that reason aemVersion was set to 6.5.13.
# 2. As of creating this script, if for project generation Java 11+ is used, it will result
#    in unformatted `{basedir}/pom.xml` (see bug description: https://issues.apache.org/jira/browse/ARCHETYPE-587).
#    In order to avoid it, Java 8 is used.
# 3. Use -SNAPSHOT version so that the bundle will be overwritten every time it is reinstalled
#    (details: https://sling.apache.org/documentation/bundles/osgi-installer.html#:~:text=The%20OSGi%20installer%20is%20a,for%20the%20OSGi%20configuration%20admin)

source "$HOME/.sdkman/bin/sdkman-init.sh" # To make sdk command work

currentDir=$(pwd)
appId="firsthops"
targetDir="${currentDir}/${appId}"
allPom="$targetDir/all/pom.xml"
corePom="$targetDir/core/pom.xml"
parentPom="$targetDir/pom.xml"
latestConditionalLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/conditional/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
latestSneakyFunLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/sneakyfun/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)

sdk use java 8.0.345-tem

mvn -B org.apache.maven.plugins:maven-archetype-plugin:3.2.1:generate \
    -D archetypeGroupId=com.adobe.aem \
    -D archetypeArtifactId=aem-project-archetype \
    -D archetypeVersion=40 \
    -D appTitle="First Hops" \
    -D appId="$appId" \
    -D groupId="eu.ciechanowiec" \
    -D artifactId="$appId" \
    -D package="eu.ciechanowiec.$appId" \
    -D singleCountry=n \
    -D includeExamples=y \
    -D version="1.0-SNAPSHOT" \
    -D aemVersion="6.5.13"

sdk use java 11.0.16-tem

cd "$targetDir" || exit 1
git init
git add .
git commit -m "Init commit"

# ADJUST ALL POM
allPomFirstPart=$(head -n 56 "$allPom")
allPomSecondPart=$(tail -n +57 "$allPom")
echo "$allPomFirstPart" > "$allPom"
cat >> "$allPom" << EOF
                        <embedded>
                            <groupId>eu.ciechanowiec</groupId>
                            <artifactId>conditional</artifactId>
                            <target>/apps/firsthops-vendor-packages/application/install</target>
                        </embedded>
                        <embedded>
                            <groupId>eu.ciechanowiec</groupId>
                            <artifactId>sneakyfun</artifactId>
                            <target>/apps/firsthops-vendor-packages/application/install</target>
                        </embedded>
EOF
echo "$allPomSecondPart" >> "$allPom"

# ADJUST CORE POM
corePomFirstPart=$(head -n 83 "$corePom")
corePomSecondPart=$(tail -n +84 "$corePom")
echo "$corePomFirstPart" > "$corePom"
cat >> "$corePom" << EOF
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.24</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>eu.ciechanowiec</groupId>
            <artifactId>conditional</artifactId>
            <version>$latestConditionalLibVersion</version>
        </dependency>
        <dependency>
            <groupId>eu.ciechanowiec</groupId>
            <artifactId>sneakyfun</artifactId>
            <version>$latestSneakyFunLibVersion</version>
        </dependency>
EOF
echo "$corePomSecondPart" >> "$corePom"

# ADJUST PARENT POM
sed -i 's/<source>1.8<\/source>/<source>11<\/source>/g' "$parentPom"
sed -i 's/<target>1.8<\/target>/<target>11<\/target>/g' "$parentPom"
parentPomFirstPart=$(head -n 179 "$parentPom")
parentPomSecondPart=$(tail -n +182 "$parentPom")
echo "$parentPomFirstPart" > "$parentPom"
cat >> "$parentPom" << EOF
# Plugins are inlined due to the plugins merge bug: https://github.com/adobe/aem-project-archetype/issues/971
-plugin org.apache.sling.caconfig.bndplugin.ConfigurationClassScannerPlugin,org.apache.sling.bnd.models.ModelsScannerPlugin
EOF
echo "$parentPomSecondPart" >> "$parentPom"

git add .
git commit -m "Add libraries, migrate to Java 11, fix bnd bug"

cd "$currentDir" || exit 1
