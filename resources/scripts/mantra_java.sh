#!/bin/bash

# Script for generating Java projects from a template
# Author: herman@ciechanowiec.eu
# heredoc used in the script below should adhere to the left border of a file
# Table of Contents:
#    1. Formats
#    2. Functions
#    3. Configuration block
#    4. Driver code

# ============================================== #
#                                                #
#                    FORMATS                     #
#                                                #
# ============================================== #

BOLD="\e[1m"
BOLD_RED="\e[1;91m"
BOLD_LIGHT_CYAN="\e[1;96m"
BOLD_LIGHT_YELLOW="\e[1;93m"
BOLD_LIGHT_GREEN="\e[1;92m"
ITALIC="\e[3m"
RESET_FORMAT="\e[0m"
ERROR_TAG="${BOLD_RED}[ERROR]:${RESET_FORMAT}"
STATUS_TAG="${BOLD_LIGHT_CYAN}[STATUS]:${RESET_FORMAT}"

# ============================================== #
#                                                #
#                   FUNCTIONS                    #
#                                                #
# ============================================== #

showWelcomeMessage () {
	printf "${BOLD}=====================\n"
	printf "MANTRA SCRIPT STARTED\n"
	printf "=====================${RESET_FORMAT}\n"
}

verifyIfTreeExists () {
	if ! command tree -v &> /dev/null
	then
		printf "${ERROR_TAG} 'tree' package which is required to run the script hasn't been detected. The script execution has been aborted. Try to install 'tree' package using this command: 'sudo apt install tree'.\n"
    exit
	fi
}

verifyIfGitExists () {
	if ! command git --version &> /dev/null
	then
		printf "${ERROR_TAG} 'git' package which is required to run the script hasn't been detected. The script execution has been aborted. Try to install 'git' package using this command: 'sudo apt install git'.\n"
		exit
	fi
}

verifyIfExactlyOneArgument () {
	if [ $# != 1 ]
	then
    printf "${ERROR_TAG} The script must be provided with exactly one argument: the project name. This condition hasn't been met and the script execution has been aborted.\n"
		exit
	fi
}

verifyIfCorrectPathUntilProjectDirectory () {
  pathUntilProjectDirectory=$1
	if [[ ! "$pathUntilProjectDirectory" =~ ^\/.* ]] || [ ! -d "$pathUntilProjectDirectory" ]
	then
		printf "${ERROR_TAG} Misconfigured path where the project directory should be created. That should be an absolute path for the existing directory. The script execution has been aborted.\n"
		exit
	fi
}

verifyIfCorrectProjectName () {
  projectName=$1
	if [[ ! "$projectName" =~ ^[a-z]{1}([a-z0-9]*)$ ]]
	then
		printf "${ERROR_TAG} The provided project name may consist only of lower case ASCII letters and numbers. The first character should be an ASCII letter. This condition hasn't been met and the script execution has been aborted.\n"
		exit
	fi
}

verifyIfProjectPathIsFree () {
  projectDirectory=$1
	if [ -d "$projectDirectory" ]
	then
		printf "${ERROR_TAG} The specified project path is occupied: ${ITALIC}$projectDirectory${RESET_FORMAT}. The script execution has been aborted.\n"
		exit
	fi
}

createProjectDirectory () {
  projectDirectory=$1
	mkdir -p "$projectDirectory"
	printf "${STATUS_TAG} The project directory ${ITALIC}$projectDirectory${RESET_FORMAT} has been created.\n"
}

createSrcStructure () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
	mkdir -p "$projectDirectory"/src/{main/{java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName",resources},test/java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName"}
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java"
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/SamplePrinter.java"
	touch "$projectDirectory/src/main/resources/tinylog.properties"
	touch "$projectDirectory/src/main/resources/sampleLines.txt"
	touch "$projectDirectory/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java"
	printf "${STATUS_TAG} File structure for ${ITALIC}src${RESET_FORMAT} has been created.\n"
}

insertContentToMain () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  mainFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java"
cat > "$mainFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import lombok.extern.slf4j.Slf4j;

@Slf4j
class Main {

    public static void main(String[] args) {
        log.info("Application started");
        System.out.println("Hello, Universe!");

        log.info("Testing resource printing...");
        SamplePrinter samplePrinter = new SamplePrinter();
        samplePrinter.performSamplePrint("sampleLines.txt");
        log.info("Finished resource printing");

        log.info("Application ended");
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}Main.java${RESET_FORMAT}.\n"
}

insertContentToSamplePrinter () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  samplePrinterFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/SamplePrinter.java"
cat > "$samplePrinterFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import lombok.extern.slf4j.Slf4j;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

@Slf4j
class SamplePrinter {

    void performSamplePrint(String fileName) {
        InputStream fileFromResourcesAsStream = getFileFromResourcesAsStream(fileName);
        printInputStream(fileFromResourcesAsStream);
    }

    private InputStream getFileFromResourcesAsStream(String fileName) {
        Class<? extends SamplePrinter> samplePrinterClass = this.getClass();
        ClassLoader classLoader = samplePrinterClass.getClassLoader();
        InputStream inputStream = classLoader.getResourceAsStream(fileName);
        if (inputStream == null) {
            throw new IllegalArgumentException(String.format("File '%s' wasn't found!", fileName));
        } else {
            return inputStream;
        }
    }

    private static void printInputStream(InputStream inputStream) {
        try (InputStreamReader streamReader = new InputStreamReader(inputStream, StandardCharsets.UTF_8);
             BufferedReader reader = new BufferedReader(streamReader)) {
            String line = reader.readLine();
            while (line != null) {
                System.out.println(line);
                line = reader.readLine();
            }
        } catch (IOException exception) {
            log.error("Failed to print input stream", exception);
        }
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}SamplePrinter.java${RESET_FORMAT}.\n"
}

insertContentToSampleLines () {
  sampleLinesFile="$1/src/main/resources/sampleLines.txt"
cat > "$sampleLinesFile" << EOF
This is the first line from a sample file.
This is the second line from a sample file.
EOF
printf "${STATUS_TAG} Default text content has been added to ${ITALIC}sampleLines.txt${RESET_FORMAT}.\n"
}

insertContentToLoggerProperties () {
  loggerPropertiesFile="$1/src/main/resources/tinylog.properties"
cat > "$loggerPropertiesFile" << EOF
writer        = console
# to write to a file:
# writer        = file
level         = debug
writer.format = [{date: yyyy-MM-dd HH:mm:ss.SSS O}] [{thread}] [{class}] [{level}]: {message}
writer.file   = logs.txt
EOF
printf "${STATUS_TAG} Default logger properties have been added to ${ITALIC}tinylog.properties${RESET_FORMAT}.\n"
}

insertContentToMainTest () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  mainTestFile="$projectDirectory/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java"
cat > "$mainTestFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(MockitoExtension.class)
class MainTest {

    @Test
    void sampleTrueTest() {
        assertTrue(true);
    }
}
EOF
printf "${STATUS_TAG} Default test content has been added to ${ITALIC}MainTest.java${RESET_FORMAT}.\n"
}

addGitAttributes () {
  projectDirectory=$1
  gitattributesFile="$projectDirectory/.gitattributes"
  touch "$gitattributesFile"
cat > "$gitattributesFile" << EOF
###############################
#        Line Endings         #
###############################

# Set default behaviour to automatically normalize line endings:
* text=auto

# Force batch scripts to always use CRLF line endings so that if a repo is accessed
# in Windows via a file share from Linux, the scripts will work:
*.{cmd,[cC][mM][dD]} text eol=crlf
*.{bat,[bB][aA][tT]} text eol=crlf

# Force bash scripts to always use LF line endings so that if a repo is accessed
# in Unix via a file share from Windows, the scripts will work:
*.sh text eol=lf
EOF
printf "${STATUS_TAG} ${ITALIC}.gitattributes${RESET_FORMAT} with default content has been created.\n"
}

addGitignore () {
  projectDirectory=$1
  gitignoreFile="$projectDirectory/.gitignore"
  touch "$gitignoreFile"
cat > "$gitignoreFile" << EOF
*.class
*.iml
*.log
.idea
.vscode
target
# Compiled documentation:
README.html
README.pdf
EOF
printf "${STATUS_TAG} ${ITALIC}.gitignore${RESET_FORMAT} with default content has been created.\n"
}

addLicense () {
  licenseFile="$projectDirectory/LICENSE.txt"
  projectDirectory=$1
  gitCommitterName=$2
  gitCommitterSurname=$3
  year=$(date +%Y)
  touch "$licenseFile"
cat > "$licenseFile" << EOF
The program is subject to MIT No Attribution License

Copyright © $year $gitCommitterName $gitCommitterSurname

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

The Software is provided 'as is', without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the use or other dealings in the Software.
EOF
printf "${STATUS_TAG} ${ITALIC}.gitignore${RESET_FORMAT} with default content has been created.\n"
}

addPom () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  projectURL=$5
  pomFile="$projectDirectory/pom.xml"
  touch "$pomFile"
  latestConditionalLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/conditional/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
cat > "$pomFile" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>$firstLevelPackageName.$secondLevelPackageName</groupId>
  <artifactId>$projectName</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>

  <inceptionYear>$(date +%Y)</inceptionYear>

  <name>$projectName</name>
  <description>Java Program</description>
  <url>$projectURL</url>

  <properties>
    <!--  Building properties  -->
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <maven.compiler.release>17</maven.compiler.release>
    <!--  Dependencies  -->
    <conditional.version>$latestConditionalLibVersion</conditional.version>
    <commons-lang3.version>3.12.0</commons-lang3.version>
    <lombok.version>1.18.24</lombok.version>
    <jsr305.version>3.0.2</jsr305.version>
    <junit-jupiter-api.version>5.9.1</junit-jupiter-api.version>
    <junit-jupiter-params.version>5.9.1</junit-jupiter-params.version>
    <mockito-core.version>4.10.0</mockito-core.version>
    <mockito-junit-jupiter.version>4.10.0</mockito-junit-jupiter.version>
    <mockito-inline.version>4.10.0</mockito-inline.version>
    <slf4j-api.version>2.0.6</slf4j-api.version>
    <slf4j-tinylog.version>2.5.0</slf4j-tinylog.version>
    <tinylog-api.version>2.5.0</tinylog-api.version>
    <tinylog-impl.version>2.5.0</tinylog-impl.version>
    <spotbugs-annotations.version>4.7.3</spotbugs-annotations.version>
    <maven-project-info-reports-plugin.version>3.4.1</maven-project-info-reports-plugin.version>
    <!-- Locking down Maven default plugins -->
    <maven-clean-plugin.version>3.2.0</maven-clean-plugin.version>
    <maven-deploy-plugin.version>3.0.0</maven-deploy-plugin.version>
    <maven-install-plugin.version>3.0.1</maven-install-plugin.version>
    <maven-jar-plugin.version>3.3.0</maven-jar-plugin.version>
    <maven-resources-plugin.version>3.3.0</maven-resources-plugin.version>
    <maven-site-plugin.version>3.12.1</maven-site-plugin.version>
    <!-- Plugins -->
    <maven-compiler-plugin.version>3.10.1</maven-compiler-plugin.version>
    <maven-shade-plugin.version>3.4.0</maven-shade-plugin.version>
    <maven-dependency-plugin.version>3.3.0</maven-dependency-plugin.version>
    <maven-surefire-plugin.version>3.0.0-M7</maven-surefire-plugin.version>
    <maven-failsafe-plugin.version>3.0.0-M7</maven-failsafe-plugin.version>
    <maven-enforcer-plugin.version>3.1.0</maven-enforcer-plugin.version>
    <min.maven.version>3.8.6</min.maven.version>
    <versions-maven-plugin.version>2.12.0</versions-maven-plugin.version>
    <jacoco-maven-plugin.version>0.8.8</jacoco-maven-plugin.version>
    <jacoco-maven-plugin.coverage.minimum>0</jacoco-maven-plugin.coverage.minimum>
    <spotbugs-maven-plugin.version>4.7.3.0</spotbugs-maven-plugin.version>
  </properties>

  <dependencies>
    <!-- Utils -->
    <dependency>
      <groupId>eu.ciechanowiec</groupId>
      <artifactId>conditional</artifactId>
      <version>\${conditional.version}</version>
    </dependency>
    <dependency>
      <groupId>org.apache.commons</groupId>
      <artifactId>commons-lang3</artifactId>
      <version>\${commons-lang3.version}</version>
    </dependency>
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <version>\${lombok.version}</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <!--  Mainly for @CheckForNull and @Nonnull annotations.
            Google groupId is used, because the native groupId isn't
            available at repo.maven.apache.org/maven2 -->
      <groupId>com.google.code.findbugs</groupId>
      <artifactId>jsr305</artifactId>
      <version>\${jsr305.version}</version>
    </dependency>
    <!-- Testing -->
    <dependency>
      <!--  Basic JUnit library -->
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter-api</artifactId>
      <version>\${junit-jupiter-api.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <!-- Parameterized JUnit tests -->
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter-params</artifactId>
      <version>\${junit-jupiter-params.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <!-- Basic Mockito library -->
      <groupId>org.mockito</groupId>
      <artifactId>mockito-core</artifactId>
      <version>\${mockito-core.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <!-- JUnit extension for Mockito: @ExtendWith(MockitoExtension.class) -->
      <groupId>org.mockito</groupId>
      <artifactId>mockito-junit-jupiter</artifactId>
      <version>\${mockito-junit-jupiter.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <!-- Experimental and intermediate library for mocking
           final types, enums, final and static methods.
           Will be superseded by automatic usage in a future version -->
      <groupId>org.mockito</groupId>
      <artifactId>mockito-inline</artifactId>
      <version>\${mockito-inline.version}</version>
      <scope>test</scope>
    </dependency>
    <!-- Logging -->
    <dependency>
      <!-- Logging facade -->
      <groupId>org.slf4j</groupId>
      <artifactId>slf4j-api</artifactId>
      <version>\${slf4j-api.version}</version>
    </dependency>
    <dependency>
      <!-- Tinylog to SLF4J binding -->
      <groupId>org.tinylog</groupId>
      <artifactId>slf4j-tinylog</artifactId>
      <version>\${slf4j-tinylog.version}</version>
    </dependency>
    <dependency>
      <!-- Tinylog API -->
      <groupId>org.tinylog</groupId>
      <artifactId>tinylog-api</artifactId>
      <version>\${tinylog-api.version}</version>
    </dependency>
    <dependency>
      <!-- Tinylog implementation -->
      <groupId>org.tinylog</groupId>
      <artifactId>tinylog-impl</artifactId>
      <version>\${tinylog-impl.version}</version>
    </dependency>
    <dependency>
      <!-- @SuppressFBWarnings annotation for SpotBugs: -->
      <groupId>com.github.spotbugs</groupId>
      <artifactId>spotbugs-annotations</artifactId>
      <version>\${spotbugs-annotations.version}</version>
      <optional>true</optional>
      <!-- Although @SuppressFBWarnings annotation, for which this dependency is added,
           has a CLASS retention policy, in fact it isn't required during runtime or
           on the final classpath -->
      <scope>provided</scope>
    </dependency>
  </dependencies>

  <build>
    <resources>
      <resource>
        <!-- Describes the directory where the resources are stored.
             The path is relative to the POM -->
        <directory>src/main/resources</directory>
      </resource>
    </resources>

    <pluginManagement>
      <!-- Lock down plugins versions to avoid using Maven
           defaults from the default Maven super-pom -->
      <plugins>
        <plugin>
          <artifactId>maven-clean-plugin</artifactId>
          <version>\${maven-clean-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-deploy-plugin</artifactId>
          <version>\${maven-deploy-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-install-plugin</artifactId>
          <version>\${maven-install-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-jar-plugin</artifactId>
          <version>\${maven-jar-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-resources-plugin</artifactId>
          <version>\${maven-resources-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-site-plugin</artifactId>
          <version>\${maven-site-plugin.version}</version>
        </plugin>
        <plugin>
          <artifactId>maven-project-info-reports-plugin</artifactId>
          <version>\${maven-project-info-reports-plugin.version}</version>
        </plugin>
      </plugins>
    </pluginManagement>

    <plugins>
      <!-- Allows to compile and build the program -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>\${maven-compiler-plugin.version}</version>
      </plugin>
      <!-- Processes resources -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-resources-plugin</artifactId>
        <executions>
          <execution>
            <id>copy-license-and-readme-to-jar</id>
            <phase>process-resources</phase>
            <goals>
              <goal>copy-resources</goal>
            </goals>
            <configuration>
              <outputDirectory>\${project.build.outputDirectory}</outputDirectory>
              <resources>
                <resource>
                  <directory>\${project.basedir}</directory>
                  <includes>
                    <include>LICENSE.txt</include>
                    <include>README.adoc</include>
                  </includes>
                </resource>
              </resources>
            </configuration>
          </execution>
        </executions>
      </plugin>
      <!-- Creates an uber-jar binary file with all
           dependencies and resources inside -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-shade-plugin</artifactId>
        <version>\${maven-shade-plugin.version}</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>shade</goal>
            </goals>
            <configuration>
              <transformers>
                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                  <mainClass>$firstLevelPackageName.$secondLevelPackageName.$projectName.Main</mainClass>
                </transformer>
              </transformers>
              <filters>
                <filter>
                  <artifact>*:*</artifact>
                  <excludes>
                    <exclude>META-INF/*.MF</exclude>
                    <exclude>META-INF/NOTICE.txt</exclude>
                    <exclude>META-INF/LICENSE.txt</exclude>
                    <exclude>META-INF/versions/9/module-info.class</exclude>
                  </excludes>
                </filter>
              </filters>
            </configuration>
          </execution>
        </executions>
        <configuration>
          <createDependencyReducedPom>false</createDependencyReducedPom>
        </configuration>
      </plugin>
      <!-- Reports on unused dependencies: -->
      <plugin>
          <groupId>org.apache.maven.plugins</groupId>
          <artifactId>maven-dependency-plugin</artifactId>
          <version>\${maven-dependency-plugin.version}</version>
        <executions>
          <execution>
            <goals>
              <goal>analyze</goal>
            </goals>
            <phase>package</phase>
          </execution>
        </executions>
        <configuration>
          <ignoreNonCompile>true</ignoreNonCompile>
        </configuration>
      </plugin>
      <!-- Prevents from building if unit tests don't pass
           and fails the build if there are no tests -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>\${maven-surefire-plugin.version}</version>
        <configuration>
          <failIfNoTests>true</failIfNoTests>
        </configuration>
      </plugin>
      <!-- Prevents from building if integration tests don't pass -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-failsafe-plugin</artifactId>
        <version>\${maven-failsafe-plugin.version}</version>
        <executions>
          <execution>
            <goals>
              <goal>integration-test</goal>
              <goal>verify</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
      <!-- Requires new Maven version -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-enforcer-plugin</artifactId>
        <version>\${maven-enforcer-plugin.version}</version>
        <executions>
          <execution>
            <id>enforce-maven</id>
            <goals>
              <goal>enforce</goal>
            </goals>
            <configuration>
              <rules>
                <requireMavenVersion>
                  <version>[\${min.maven.version},)</version>
                </requireMavenVersion>
              </rules>
            </configuration>
          </execution>
        </executions>
      </plugin>
      <!-- Reports on possible updates of dependencies and plugins -->
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>versions-maven-plugin</artifactId>
        <version>\${versions-maven-plugin.version}</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>display-dependency-updates</goal>
              <goal>display-plugin-updates</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
      <!-- Creates reports on tests coverage (target->site->jacoco->index.html)
           and fails the build if the coverage is insufficient -->
      <plugin>
        <groupId>org.jacoco</groupId>
        <artifactId>jacoco-maven-plugin</artifactId>
        <version>\${jacoco-maven-plugin.version}</version>
        <executions>
          <execution>
            <id>prepare-agent</id>
            <goals>
              <goal>prepare-agent</goal>
            </goals>
          </execution>
          <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
              <goal>report</goal>
            </goals>
          </execution>
          <execution>
            <id>check</id>
            <phase>prepare-package</phase>
            <goals>
              <goal>check</goal>
            </goals>
            <configuration>
              <rules>
                <rule>
                  <element>BUNDLE</element>
                  <limits>
                    <limit>
                      <counter>INSTRUCTION</counter>
                      <value>COVEREDRATIO</value>
                      <minimum>\${jacoco-maven-plugin.coverage.minimum}</minimum>
                    </limit>
                    <limit>
                      <counter>BRANCH</counter>
                      <value>COVEREDRATIO</value>
                      <minimum>\${jacoco-maven-plugin.coverage.minimum}</minimum>
                    </limit>
                  </limits>
                </rule>
              </rules>
            </configuration>
          </execution>
        </executions>
      </plugin>
      <!-- Searches for bugs during the build -->
      <plugin>
        <groupId>com.github.spotbugs</groupId>
        <artifactId>spotbugs-maven-plugin</artifactId>
        <version>\${spotbugs-maven-plugin.version}</version>
        <configuration>
          <failOnError>true</failOnError>
          <includeTests>true</includeTests>
          <effort>Max</effort>
          <!-- Low / Medium / High: -->
          <threshold>Low</threshold>
        </configuration>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>check</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF
printf "${STATUS_TAG} ${ITALIC}pom.xml${RESET_FORMAT} file with default content has been created.\n"
}

addReadme () {
  readmeFile="$1/README.adoc"
  projectName=$2
  gitCommitterName=$3
  gitCommitterSurname=$4
  gitCommitterEmail=$5
  date=$(date +%F)
  year=$(date +%Y)
  touch "$readmeFile"
cat > "$readmeFile" << EOF
[.text-justify]
= $projectName
:reproducible:
:doctype: article
:author: $gitCommitterName $gitCommitterSurname
:email: $gitCommitterEmail
:chapter-signifier:
:sectnums:
:sectnumlevels: 5
:sectanchors:
:toc: left
:toclevels: 5
:icons: font

ifndef::backend-pdf[]
++++
<style>
p {
    text-align: justify;
    text-justify: inter-word;
}
img {
    display: block;
    margin: 0 auto;
}
.imageblock .title {
    text-align: center;
}
::-webkit-scrollbar {
    width: 12px;
    height: 10px;
}
::-webkit-scrollbar-track {
    box-shadow: 0 0 1px 1px #111;
}
::-webkit-scrollbar-thumb {
    border-radius: 3px;
    box-shadow: inset 0 0 0 0.7px;
}
::-webkit-scrollbar-thumb:hover {
    background: #f1f1f1;
}
::-webkit-scrollbar-thumb:active {
    background: #eae9e9;
}
#footer {
    background: #fff;
}
.admonitionblock>table td.content {
    color: rgba(0,0,0,.8) !important;
}
</style>
++++
endif::[]

This program was created on _${date}_ from a template.

== License
The program is subject to MIT No Attribution License

Copyright © $year $gitCommitterName $gitCommitterSurname

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

The Software is provided 'as is', without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the use or other dealings in the Software.
EOF
printf "${STATUS_TAG} ${ITALIC}README.adoc${RESET_FORMAT} file with default content has been created.\n"
}

initGit () {
	projectDirectory=$1
	git init "$projectDirectory" &> /dev/null   # Redirect to void hints on git initialization
	printf "${STATUS_TAG} Git repository has been initialized.\n"
}

setupGitCommitter() {
	projectDirectory=$1
	gitCommitterName=$2
	gitCommitterSurname=$3
	gitCommitterEmail=$4
	currentDirectory=$(pwd)
	cd "$projectDirectory" || exit 1
	git config user.name "$gitCommitterName $gitCommitterSurname"
	git config user.email $gitCommitterEmail
	printf "${STATUS_TAG} Git committer fot this project has been set up: $gitCommitterName $gitCommitterSurname <$gitCommitterEmail>.\n"
	cd "$currentDirectory" || exit 1
}

showFinishMessage () {
	projectName=$1
	printf "${BOLD_LIGHT_GREEN}[SUCCESS]:${RESET_FORMAT} The project ${ITALIC}$projectName${RESET_FORMAT} with the following file structure has been created:\n"
  tree --dirsfirst -a "$projectDirectory"
}

openProjectInIDE () {
  launcherPath=$1
  projectDirectory=$2
  if [ ! -f "$launcherPath" ]
      then
        printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT}hasn't been detected. Opening will be aborted.\n"
        exit 1
      else
        printf "${BOLD_LIGHT_YELLOW}[IntelliJ IDEA]:${RESET_FORMAT} Opening the project...\n"
        nohup "$launcherPath" nosplash "$projectDirectory" > /dev/null 2>&1 &
    fi
}

# ============================================== #
#                                                #
#              CONFIGURATION BLOCK               #
#                                                #
# ============================================== #

# Revise and change values of the variables below to meet your needs

gitCommitterName="Herman"
gitCommitterSurname="Ciechanowiec"
gitCommitterEmail="herman@ciechanowiec.eu"
firstLevelPackageName="eu"
secondLevelPackageName="ciechanowiec"
projectURL="https://ciechanowiec.eu/"
pathUntilProjectDirectory="${HOME}/0_prog"  # This directory must exist when script executes
# It is assumed that the project will be opened in IntelliJ IDEA Ultimate.
# In case you want to use IntelliJ IDEA Community, comment out the code line below
#    and restore from the comment the next line:
launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"
#launcherPath="/snap/intellij-idea-community/current/bin/idea.sh"

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

showWelcomeMessage
verifyIfTreeExists
verifyIfGitExists
verifyIfExactlyOneArgument "$@"

projectName=$1 # First passed argument
projectDirectory="$pathUntilProjectDirectory/$1"
verifyIfCorrectPathUntilProjectDirectory "$pathUntilProjectDirectory"
verifyIfCorrectProjectName "$projectName"
verifyIfProjectPathIsFree "$projectDirectory"

createProjectDirectory "$projectDirectory"

# Pollute 'src' folder:
createSrcStructure "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"
insertContentToMain "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"
insertContentToSamplePrinter "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"
insertContentToSampleLines "$projectDirectory"
insertContentToLoggerProperties "$projectDirectory"
insertContentToMainTest "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"

# Pollute root directory with additional files:
addGitAttributes "$projectDirectory"
addGitignore "$projectDirectory"
addLicense "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname"
addPom "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName" "$projectURL"
addReadme "$projectDirectory" "$projectName" "$gitCommitterName" "$gitCommitterSurname" "$gitCommitterEmail"

# Setup git:
initGit "$projectDirectory"
setupGitCommitter "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname" "$gitCommitterEmail"

# Finish:
showFinishMessage "$projectName"
openProjectInIDE "$launcherPath" "$projectDirectory"
