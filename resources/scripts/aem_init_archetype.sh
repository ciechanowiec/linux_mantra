#!/bin/bash
# 1. For AEM 6.5 the archetype below works on for AEM 6.5.16.
#    However, AEM 6.5.16 is supposed to work with 6.5.15 uber-jar.
#    For that reason aemVersionToUse is set for AEM 6.5 to 6.5.15.
# 2. As of creating this script, if for project generation Java 11+ is used, it will result
#    in unformatted `{basedir}/pom.xml` (see bug description: https://issues.apache.org/jira/browse/ARCHETYPE-587).
#    In order to avoid it, Java 8 is used.
# 3. Use -SNAPSHOT version so that the bundle will be overwritten every time it is reinstalled
#    (details: https://sling.apache.org/documentation/bundles/osgi-installer.html#:~:text=The%20OSGi%20installer%20is%20a,for%20the%20OSGi%20configuration%20admin)

source "$HOME/.sdkman/bin/sdkman-init.sh" # To make sdk command work

userInput=$1
aemVersionToUse=""
if [ "$userInput" == "cloud" ]; then
    aemVersionToUse="cloud"
    elif [ "$userInput" == "65" ]; then
      aemVersionToUse="6.5.15"
    else
      echo "Unknown AEM version. Aborting..."
      exit 1
fi

currentDir=$(pwd)
appId="firsthops"
targetDir="${currentDir}/${appId}"
allPom="$targetDir/all/pom.xml"
corePom="$targetDir/core/pom.xml"
parentPom="$targetDir/pom.xml"
latestConditionalLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/conditional/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
latestSneakyFunLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/sneakyfun/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)

sdk use java 8.0.412-zulu

mvn -B org.apache.maven.plugins:maven-archetype-plugin:3.2.1:generate \
    -D archetypeGroupId=com.adobe.aem \
    -D archetypeArtifactId=aem-project-archetype \
    -D archetypeVersion=50 \
    -D appTitle="First Hops" \
    -D appId="$appId" \
    -D groupId="eu.ciechanowiec" \
    -D artifactId="$appId" \
    -D package="eu.ciechanowiec.$appId" \
    -D singleCountry=n \
    -D includeExamples=y \
    -D version="1.0-SNAPSHOT" \
    -D aemVersion="$aemVersionToUse"

sdk use java 11.0.23-tem

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
sed -i.backup 's/Import-Package: javax.annotation/Import-Package: !lombok,javax.annotation/g' "$corePom"
trash-put "${corePom}.backup"
corePomFirstPart=$(head -n 83 "$corePom")
corePomSecondPart=$(tail -n +84 "$corePom")
echo "$corePomFirstPart" > "$corePom"
cat >> "$corePom" << EOF
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.30</version>
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
sed -i.backup 's/<source>1.8<\/source>/<source>11<\/source>/g' "$parentPom"
sed -i.backup 's/<target>1.8<\/target>/<target>11<\/target>/g' "$parentPom"
trash-put "${parentPom}.backup"
parentPomFirstPart=$(head -n 181 "$parentPom")
parentPomSecondPart=$(tail -n +185 "$parentPom")
echo "$parentPomFirstPart" > "$parentPom"
cat >> "$parentPom" << EOF

# Plugins are inlined due to the plugins merge bug: https://github.com/adobe/aem-project-archetype/issues/971
-plugin org.apache.sling.caconfig.bndplugin.ConfigurationClassScannerPlugin,org.apache.sling.bnd.models.ModelsScannerPlugin
EOF
echo "$parentPomSecondPart" >> "$parentPom"

git add .
git commit -m "Add libraries, migrate to Java 11, fix bnd bug"

cd "$currentDir" || exit 1
