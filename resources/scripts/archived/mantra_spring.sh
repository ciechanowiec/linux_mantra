#!/bin/bash

# ============================================== #
#                                                #
#                   FUNCTIONS                    #
#                                                #
# ============================================== #

showWelcomeMessage () {
	printf "\n\e[1m=====================\n"
	printf "MANTRA SCRIPT STARTED\n"
	printf "=====================\e[0m\n"
}

verifyIfTreeExists () {
	if ! command tree -v &> /dev/null
	then
		printf "\e[1;91m[ERROR]:\e[0m 'tree' package which is needed to run the script hasn't been detected and the script has stopped. Try to install 'tree' package using command 'sudo apt install tree'.\n\n"
    		exit
	fi
}

verifyIfGitExists () {
	if ! command git --version &> /dev/null
	then
		printf "\e[1;91m[ERROR]:\e[0m 'git' package which is needed to run the script hasn't been detected and the script has stopped. Try to install 'git' package using command 'sudo apt install git'.\n\n"
		exit
	fi
}

verifyIfTwoArguments () {	
	if [ $# != 2 ]
	then
		printf "\e[1;91m[ERROR]:\e[0m The script must be provided with exactly two arguments. The first one should be an absolute path where the project directory is to be created and the second one should be the project name. This condition hasn't been met and the script has stopped.\n\n"
		exit
	fi
}

verifyIfOneArgument () {
	if [ $# != 1 ]
	then
    		printf "\e[1;91m[ERROR]:\e[0m The script must be provided with exactly one argument: the project name. This condition hasn't been met and the script has stopped.\n\n"
		exit
	fi
}

verifyIfCorrectPath () {
pathUntilProjectDirectory=$1
	if [[ ! "$pathUntilProjectDirectory" =~ ^\/.* ]]
	then
		printf "\e[1;91m[ERROR]:\e[0m As the first argument for the script an absolute path where the project directory is to be created should be provided. This condition hasn't been met and the script has stopped.\n\n"
		exit
	fi
}

verifyIfCorrectName () {
projectName=$1
	if [[ ! "$projectName" =~ ^[a-z]{1}([a-z0-9]*)$ ]]
	then
		printf "\e[1;91m[ERROR]:\e[0m The provided project name may consist only of lower case letters and numbers; the first character should be a letter. This condition hasn't been met and the script has stopped.\n\n"
		exit
	fi
}

verifyIfProjectDirectoryExists () {
projectDirectory=$1
	if [ -d $projectDirectory ]
	then
		printf "\e[1;91m[ERROR]:\e[0m The project already exists in \e[3m$projectDirectory\e[0m. The script has stopped.\n\n"
		exit
	fi
}

createProjectDirectory () {
projectDirectory=$1
	mkdir -p $projectDirectory
	printf "\e[1;96m[STATUS]:\e[0m The project directory \e[3m$projectDirectory\e[0m has been created.\n"
}

createFilesStructure () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
	mkdir -p $1/src/{main/{java/$firstLevelPackageName/$secondLevelPackageName/$projectName,resources/{static,templates}},test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName}
	touch $1/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java
	touch $1/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/DefaultController.java
	touch $1/src/main/resources/application.properties
	touch $1/src/main/resources/tinylog.properties
	touch $1/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java
	touch $1/pom.xml
	touch $1/README.adoc
	touch $1/Dockerfile
	printf "\e[1;96m[STATUS]:\e[0m The following file structure for the project has been created:\n"
	tree $1
}

insertContentToMain () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
gitCommitterName=$5
gitCommitterSurname=$6
mainFile=$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java
cat > $mainFile << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.tinylog.Logger;

@SpringBootApplication
class Main {

    public static void main(String[] args) {
        Logger.info("Application started");
        SpringApplication.run(Main.class, args);
    }
}
EOF
printf "\e[1;96m[STATUS]:\e[0m Default Spring Boot content has been added to \e[3mMain.java\e[0m.\n"
}

insertContentToDefaultController () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
gitCommitterName=$5
gitCommitterSurname=$6
controllerFile=$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/DefaultController.java
cat > $controllerFile << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/")
class DefaultController {

    @GetMapping
    String index() {
        return "Hello, Universe!";
    }
}
EOF
printf "\e[1;96m[STATUS]:\e[0m Default Spring Boot content has been added to \e[3mDefaultController.java\e[0m.\n"
}

insertContentToApplicationProperties () {
applicationPropertiesFile=$1/src/main/resources/application.properties
cat > $applicationPropertiesFile << EOF
# If there is a spring-cloud-starter-config dependency declared,
# the Spring Cloud configuration should be provided or fully disabled:
spring.cloud.config.enabled=false
EOF
printf "\e[1;96m[STATUS]:\e[0m Default application properties have been added to \e[3mapplication.properties\e[0m.\n"
}

insertContentToLoggerProperties () {
loggerPropertiesFile=$1/src/main/resources/tinylog.properties
cat > $loggerPropertiesFile << EOF
writer        = console
# to write to a file:
# writer        = file
writer.format = {date: yyyy-MM-dd HH:mm:ss.SSS O} {level}: {message}
writer.file   = logs.txt
EOF
printf "\e[1;96m[STATUS]:\e[0m Default logger properties have been added to \e[3mtinylog.properties\e[0m.\n"
}

insertContentToMainTest () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
mainTestFile=$projectDirectory/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java
cat > $mainTestFile << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class MainTest {

    @Test
    void contextLoads() {
    }

}
EOF
printf "\e[1;96m[STATUS]:\e[0m Default test content has been added to \e[3mMainTest.java\e[0m.\n"
}

insertContentToPom () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
projectURL=$5
pomFile=$projectDirectory/pom.xml
cat > $pomFile << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>2.7.0</version>
    <relativePath/> <!-- lookup parent from repository -->
  </parent>

  <groupId>$firstLevelPackageName.$secondLevelPackageName.$projectName</groupId>
  <artifactId>$projectName</artifactId>
  <version>1.0</version>
  <packaging>jar</packaging>

  <name>$projectName</name>
  <description>Java Program</description>
  <url>$projectURL</url>

  <properties>
    <!-- building properties -->
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <maven.compiler.release>17</maven.compiler.release>
    <!-- override the version from Spring Boot Parent Properties-->
    <java.version>17</java.version>
    <!-- dependencies -->
    <tinylog-api.version>2.5.0-M1.1</tinylog-api.version>
    <tinylog-impl.version>2.5.0-M1.1</tinylog-impl.version>
    <!-- dependency management -->
    <!-- ATTENTION: the version of spring-cloud-dependencies should correspond to the
                    appropriate version of Spring Boot application; see details at:
                    https://spring.io/projects/spring-cloud -->
    <spring-cloud.version>2021.0.2</spring-cloud.version>
    <!-- plugins -->
    <dockerfile-maven-plugin.version>1.4.13</dockerfile-maven-plugin.version>
    <docker.image.prefix>$secondLevelPackageName</docker.image.prefix>
    <jacoco-maven-plugin.version>0.8.8</jacoco-maven-plugin.version>
  </properties>

  <dependencies>
    <!-- Spring dependencies -->
    <dependency>
      <!-- allows to build web, including RESTful, applications using Spring MVC;
           uses Apache Tomcat as the default embedded container -->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <!-- supports built in (or custom) endpoints that let to monitor and manage
           the application - such as application health, metrics, sessions, etc. -->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
      <!-- eases the creation of RESTful APIs that follow the HATEOAS
           principle when working with Spring / Spring MVC -->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-hateoas</artifactId>
    </dependency>
    <dependency>
      <!-- server-side Java template engine for both web and standalone environments;
           allows HTML to be correctly displayed in browsers and as static prototypes -->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-thymeleaf</artifactId>
    </dependency>
    <dependency>
      <!-- manages tests in Spring Boot application;
           added by default by Spring Initializr -->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <!-- Java annotation library which helps
           to reduce boilerplate code -->
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>

    <!-- microservices -->
    <dependency>
      <!-- declares the app as a client that connects to a Spring
           Cloud Config Server to fetch the application's configuration;
           to set the application as Spring Cloud Config Server, replace
           the dependency below with 'spring-cloud-config-server' -->
      <groupId>org.springframework.cloud</groupId>
      <artifactId>spring-cloud-starter-config</artifactId>
    </dependency>
<!-- the code below is intentionally commented out;
     restore it from the comment or remove for the
     production release -->
<!--    <dependency>-->
<!--      &lt;!&ndash; declares the app as a Eureka Client; to set the application-->
<!--           as Eureka Server, replace the dependency below-->
<!--           with 'spring-cloud-starter-netflix-eureka-server' &ndash;&gt;-->
<!--      <groupId>org.springframework.cloud</groupId>-->
<!--      <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>-->
<!--    </dependency>-->
<!--    <dependency>-->
<!--      &lt;!&ndash; allows for client-side load-balancing &ndash;&gt;-->
<!--      <groupId>org.springframework.cloud</groupId>-->
<!--      <artifactId>spring-cloud-starter-loadbalancer</artifactId>-->
<!--    </dependency>-->
<!--    <dependency>-->
<!--      &lt;!&ndash; dynamically generates a proxy class to-->
<!--           invoke the targeted REST service &ndash;&gt;-->
<!--      <groupId>org.springframework.cloud</groupId>-->
<!--      <artifactId>spring-cloud-starter-openfeign</artifactId>-->
<!--    </dependency>-->

    <!-- data persistence -->
    <dependency>
      <!-- allows to persist data in SQL stores with Java
           Persistence API using Spring Data and Hibernate.-->
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <!-- fast in-memory database that supports JDBC API and R2DBC access,
           with a small (2mb) footprint; supports embedded and server
           modes as well as a browser based console application -->
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
    </dependency>

    <!-- logging -->
    <dependency>
      <groupId>org.tinylog</groupId>
      <artifactId>tinylog-api</artifactId>
      <version>\${tinylog-api.version}</version>
    </dependency>
    <dependency>
      <groupId>org.tinylog</groupId>
      <artifactId>tinylog-impl</artifactId>
      <version>\${tinylog-impl.version}</version>
    </dependency>
  </dependencies>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <!-- a Bill of Materials required by Spring Cloud; it is
             added by default by Spring Initializr when adding
             Spring Cloud dependencies; details:
             https://spring.io/projects/spring-cloud-->
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-dependencies</artifactId>
        <version>\${spring-cloud.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <build>
    <plugins>
      <!-- Spring -->
      <plugin>
        <!-- allows to package executable jar or war archives, run Spring
             Boot applications, generate build information and start Spring
             Boot application prior to running integration tests -->
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude>
              <!-- this exclusion is added by default by Spring Initializr -->
              <groupId>org.projectlombok</groupId>
              <artifactId>lombok</artifactId>
            </exclude>
          </excludes>
        </configuration>
      </plugin>
      <plugin>
        <!-- for creation of a Docker image
             and publishing it to Docker Hub-->
        <groupId>com.spotify</groupId>
        <artifactId>dockerfile-maven-plugin</artifactId>
        <version>\${dockerfile-maven-plugin.version}</version>
        <configuration>
          <repository>\${docker.image.prefix}/\${project.artifactId}</repository>
          <tag>\${project.version}</tag>
          <buildArgs>
            <JAR_FILE>target/\${project.build.finalName}.jar</JAR_FILE>
          </buildArgs>
        </configuration>
        <executions>
          <execution>
            <id>default</id>
            <phase>install</phase>
            <goals>
              <goal>build</goal>
              <goal>push</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
      <!-- others -->
      <plugin>
        <!-- creates reports on tests coverage (target->site->jacoco->index.html) -->
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
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF
printf "\e[1;96m[STATUS]:\e[0m Default Maven-content has been added to \e[3mpom.xml\e[0m.\n"
}

insertContentToReadme () {
readmeFile=$1/README.adoc
projectName=$2
gitCommitterName=$3
gitCommitterSurname=$4
gitCommitterEmail=$5
date=`date +%F`
cat > $readmeFile << EOF
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

This project was created on $date from a template.
EOF
printf "\e[1;96m[STATUS]:\e[0m Default readme-content has been added to \e[3mREADME.adoc\e[0m.\n"
}

insertContentToDockerfile () {
projectDirectory=$1
firstLevelPackageName=$2
secondLevelPackageName=$3
projectName=$4
gitCommitterName=$5
gitCommitterSurname=$6
gitCommitterEmail=$7
dockerFile=$projectDirectory/Dockerfile
date=`date +%F`
cat > $dockerFile << EOF
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
#             STAGE 1             #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

# Specify the Docker image to use in the Docker runtime:
FROM openjdk:17-oracle as build

LABEL maintainer="$gitCommitterName $gitCommitterSurname <$gitCommitterEmail>"

# Define the JAR_FILE variable set by dockerfile-maven-plugin:
ARG JAR_FILE

# Add the application's jar to the container.
# This will copy the JAR file to the filestystem
# of the image named app.jar:
COPY \${JAR_FILE} app.jar

# Unpack the app.jar copied previously into
# the file system of the build image:
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf /app.jar)

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
#             STAGE 2             #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# ->>> the new image created in this stage contains the different
#      layers of a Spring Boot app instead of the complere JAR file

# Specify the Docker image to use in the Docker runtime:
FROM openjdk:17-oracle

# Add volume pointing to /tmp:
VOLUME /tmp

# Copy the different layers from the first image named 'build':
ARG DEPENDENCY=/target/dependency
COPY --from=build \${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build \${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build \${DEPENDENCY}/BOOT-INF/classes /app

# Target this service application in the image
# when the container is created:
ENTRYPOINT ["java","-cp","app:app/lib/*","$firstLevelPackageName.$secondLevelPackageName.$projectName.Main"]

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
#              HINTS              #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# To build a Docker image from your project:
#   -> mvn package dockerfile:build
# To check that the Docker image was build and added to the repository:
#   -> docker images
# To run the Docker image in the background:
#   -> docker run -d $secondLevelPackageName/$projectName:1.0
#      * docker run -d [docker_repository_name]:[docker_repository_tag]
# To run the Docker image on the specified localhost port:
#   -> docker run -p "8080:8080" $secondLevelPackageName/$projectName:1.0
#      * docker run -p "[TCP localhost port]:[Docker host port] [docker_repository_name]:[docker_repository_tag]
# List Docker containers:
#   -> docker ps
# Stop the Docker container:
#   -> docker stop [container_id]
EOF
printf "\e[1;96m[STATUS]:\e[0m Default Docker-content has been added to \e[3mDockerfile\e[0m.\n"
}

addGitignore () {
projectDirectory=$1
touch $projectDirectory/.gitignore
gitignoreFile=$projectDirectory/.gitignore
cat > $gitignoreFile << EOF
*.class
*.iml
*.log
.idea
.vscode
target
EOF
printf "\e[1;96m[STATUS]:\e[0m \e[3m.gitignore\e[0m with standard content has been created.\n"
}

addGitAttributes () {
projectDirectory=$1
touch $projectDirectory/.gitattributes
gitattributesFile=$projectDirectory/.gitattributes
cat > $gitattributesFile << EOF
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
printf "\e[1;96m[STATUS]:\e[0m \e[3m.gitattributes\e[0m has been created. It sets git to normalize line endings.\n"
}

initGit () {
	projectDirectory=$1
	git init $projectDirectory &> /dev/null
	printf "\e[1;96m[STATUS]:\e[0m Git repository has been initialized.\n"
}

setupGitCommitter() {
	projectDirectory=$1
	gitCommitterName=$2
	gitCommitterSurname=$3
	gitCommitterEmail=$4
	currentDirectory=`pwd`
	cd $projectDirectory
	git config user.name "$gitCommitterName $gitCommitterSurname"
	git config user.email $gitCommitterEmail
	printf "\e[1;96m[STATUS]:\e[0m Git committer fot this project has been set up: $gitCommitterName $gitCommitterSurname <$gitCommitterEmail>.\n"
	cd $currentDirectory
}

showFinishMessage () {
	projectName=$1
	printf "\e[1;92m[SUCCESS]:\e[0m The project \e[3m$projectName\e[0m has been created.\n"
}

tryOpenWithVSCode () {
	projectName=$1
	projectDirectory=$2
	if command code -v &> /dev/null # Checks whether VS Code CLI command ('code') exists
	then
		printf "\e[1;93m[VS Code]:\e[0m Opening the project...\n"
		code -n $projectDirectory
	fi
}

tryOpenWithIntelliJCommunity () {
	projectName=$1
	projectDirectory=$2
	if [ -f /snap/intellij-idea-community/current/bin/idea.sh ] # Checks whether a native IntelliJ IDEA launcher exists
	then
		printf "\e[1;93m[IntelliJ IDEA]:\e[0m Opening the project...\n"
		nohup /snap/intellij-idea-community/current/bin/idea.sh nosplash $projectDirectory > /dev/null 2>&1 &
	fi
}

tryOpenWithIntelliJUltimate () {
  projectName=$1
  projectDirectory=$2
  if [ -f /snap/intellij-idea-ultimate/current/bin/idea.sh ] # Checks whether a native IntelliJ IDEA launcher exists
  then
    printf "\e[1;93m[IntelliJ IDEA]:\e[0m Opening the project...\n"
    nohup /snap/intellij-idea-ultimate/current/bin/idea.sh nosplash $projectDirectory > /dev/null 2>&1 &
  fi
}

# ============================================== #
#                                                #
#                  DRIVER CODE                   #
#                                                #
# ============================================== #

showWelcomeMessage
verifyIfTreeExists
verifyIfGitExists

# >> START OF A CONFIGURABLE BLOCK
gitCommitterName="Herman"
gitCommitterSurname="Ciechanowiec"
gitCommitterEmail="herman@ciechanowiec.eu"
firstLevelPackageName="eu"
secondLevelPackageName="ciechanowiec"
projectURL="https://ciechanowiec.eu/"
# << END OF A CONFIGURABLE BLOCK

# >> START OF A CONFIGURABLE BLOCK
# A. This block allows to configure how many arguments are
#    required to be passed to the script.
# B. The first set of functions requires exactly two arguments:
#    - an absolute path where the project directory is to be created
#    - a project name
# C. The second set of functions requires exactly one argument: a project name.
#    In the second set of functions an absolute path where the project directory
#    is to be created isn't passed to the script, but is hardcoded inside it.
# D. By default the first set of functions is active while the second set is inactive
#    and commented out. To switch between them comment out the first one, restore
#    from the comment the second one and provide your own value for the variable
#    'pathUntilProjectDirectory' inside that second set.
# FIRST SET:
#verifyIfTwoArguments $@
#pathUntilProjectDirectory=$1
#projectName=$2
#projectDirectory=$1/$2
# SECOND SET:
verifyIfOneArgument $@
pathUntilProjectDirectory="/home/herman_ciechanowiec/0_prog" # change the value of this variable
projectName=$1
projectDirectory=$pathUntilProjectDirectory/$1
# << END OF A CONFIGURABLE BLOCK

projectDirectory=`echo $projectDirectory | sed 's/\/\//\//g'` # replace possible double // with single /

verifyIfCorrectPath $pathUntilProjectDirectory
verifyIfCorrectName $projectName
verifyIfProjectDirectoryExists $projectDirectory
createProjectDirectory $projectDirectory
createFilesStructure $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName
insertContentToMain $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName $gitCommitterName $gitCommitterSurname
insertContentToDefaultController $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName $gitCommitterName $gitCommitterSurname
insertContentToApplicationProperties $projectDirectory
insertContentToLoggerProperties $projectDirectory
insertContentToMainTest $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName
insertContentToPom $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName $projectURL
insertContentToReadme $projectDirectory $projectName $gitCommitterName $gitCommitterSurname $gitCommitterEmail
insertContentToDockerfile $projectDirectory $firstLevelPackageName $secondLevelPackageName $projectName $gitCommitterName $gitCommitterSurname $gitCommitterEmail
addGitignore $projectDirectory
addGitAttributes $projectDirectory
initGit $projectDirectory
setupGitCommitter $projectDirectory $gitCommitterName $gitCommitterSurname $gitCommitterEmail
showFinishMessage $projectName

# >> START OF A CONFIGURABLE BLOCK
# A. This block allows to open the project directory in the new
#    window with IntelliJ IDEA Community ('tryOpenWithIntelliJCommunity'),
#    IntelliJ IDEA Ultimate ('tryOpenWithIntelliJUltimate')
#    or Visual Studio Code ('tryOpenWithVSCode') if installed.
# B. By default the described options are disabled by commenting out
#    the functions 'tryOpenWithIntelliJCommunity' and 'tryOpenWithVSCode'. To enable one
#    of that options restore an appropriate function from the comment.
#tryOpenWithIntelliJCommunity $projectName $projectDirectory
tryOpenWithIntelliJUltimate $projectName $projectDirectory
#tryOpenWithVSCode $projectName $projectDirectory
# << END OF A CONFIGURABLE BLOCK

echo
