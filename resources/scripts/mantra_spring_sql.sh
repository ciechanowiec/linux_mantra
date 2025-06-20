#!/bin/bash
# A. Script for generating Spring Boot projects from a template.
#    The template is based on the output of the command similar to this:
#    spring init --dependencies=web,actuator,validation,data-jpa,mysql,h2,lombok \
#                --type=maven-project \
#                --group-id=eu.ciechanowiec \
#                --artifact-id=demo \
#                --version=1.0.0 \
#                --description="Spring Boot Application" \
#                --name="demo"
# B. Author: herman@ciechanowiec.eu.
# C. heredoc used in the script below should adhere to the left border of a file.
# D. Table of Contents:
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
	if ! type tree &> /dev/null
	then
		printf "${ERROR_TAG} 'tree' package which is required to run the script hasn't been detected. The script execution has been aborted.\n"
    exit
	fi
}

verifyIfGitExists () {
	if ! type git &> /dev/null
	then
		printf "${ERROR_TAG} 'git' package which is required to run the script hasn't been detected. The script execution has been aborted.\n"
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
	mkdir -p "$projectDirectory"/src/{main/{java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName"/{controller,model,repository,service},resources/static_code_analysis},test/{java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName",resources}}
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java"
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/controller/MainController.java"
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/model/Book.java"
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/repository/BooksRepository.java"
	touch "$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/service/BooksService.java"
	mkdir -p "$projectDirectory"/src/main/resources/sql/{data,schema}
	touch "$projectDirectory"/src/main/resources/sql/data/test-data.sql
	touch "$projectDirectory"/src/main/resources/sql/schema/prod-schema.sql
	touch "$projectDirectory"/src/main/resources/sql/schema/test-schema.sql
	touch "$projectDirectory/src/main/resources/application.properties"
	touch "$projectDirectory/src/main/resources/application-h2.properties"
	touch "$projectDirectory/src/main/resources/application-prod.properties"
	touch "$projectDirectory/src/main/resources/application-test.properties"
	touch "$projectDirectory/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java"
	touch "$projectDirectory/src/test/resources/application.properties"
	touch "$projectDirectory/src/test/resources/logback-test.xml"
	printf "${STATUS_TAG} File structure for ${ITALIC}src${RESET_FORMAT} has been created.\n"
}

insertContentToMain () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  mainFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/Main.java"
  mainControllerFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/controller/MainController.java"
	bookFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/model/Book.java"
	booksRepositoryFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/repository/BooksRepository.java"
	booksServiceFile="$projectDirectory/src/main/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/service/BooksService.java"

cat > "$mainFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@SuppressWarnings("PMD.UseUtilityClass")
public class Main {

    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}Main.java${RESET_FORMAT}.\n"

cat > "$mainControllerFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName.controller;

import $firstLevelPackageName.$secondLevelPackageName.$projectName.model.Book;
import $firstLevelPackageName.$secondLevelPackageName.$projectName.service.BooksService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Slf4j
@RestController
public class MainController {

    private final BooksService booksService;

    @Autowired
    public MainController(BooksService booksService) {
        this.booksService = booksService;
    }

    @GetMapping("/")
    ResponseEntity<List<Book>> index() {
        log.info("Received root request");
        List<Book> allBooks = booksService.findAll();
        return new ResponseEntity<>(allBooks, HttpStatus.OK);
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}MainController.java${RESET_FORMAT}.\n"

cat > "$bookFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Getter
@ToString
@NoArgsConstructor
@EqualsAndHashCode
@Table(name = "books")
@SuppressWarnings({"JpaDataSourceORMInspection", "PMD.ImmutableField"})
public class Book {

    @Id
    @Column(name = "id")
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "title")
    private String title;

    @Column(name = "author")
    private String author;

    @Column(name = "rating")
    @Setter
    private Integer rating;

    @Column(name = "description")
    private String description;

    public Book(String title, String author, Integer rating, String description) {
        this.title = title;
        this.author = author;
        this.rating = rating;
        this.description = description;
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}Book.java${RESET_FORMAT}.\n"

cat > "$booksRepositoryFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName.repository;

import $firstLevelPackageName.$secondLevelPackageName.$projectName.model.Book;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BooksRepository extends CrudRepository<Book, Long> {
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}BooksRepository.java${RESET_FORMAT}.\n"

cat > "$booksServiceFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName.service;

import $firstLevelPackageName.$secondLevelPackageName.$projectName.model.Book;
import $firstLevelPackageName.$secondLevelPackageName.$projectName.repository.BooksRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Spliterator;
import java.util.stream.StreamSupport;

@Service
public class BooksService {

    private final BooksRepository booksRepository;

    @Autowired
    public BooksService(BooksRepository booksRepository) {
        this.booksRepository = booksRepository;
    }

    @SuppressWarnings("ChainedMethodCall")
    public List<Book> findAll() {
        Iterable<Book> allItems = booksRepository.findAll();
        Spliterator<Book> allItemsSpliterator = allItems.spliterator();
        return StreamSupport.stream(allItemsSpliterator, false)
                            .toList();
    }
}
EOF
printf "${STATUS_TAG} Default Java-content has been added to ${ITALIC}BooksService.java${RESET_FORMAT}.\n"
}

insertContentToSQLInitFiles () {
  testDataFile="$1/src/main/resources/sql/data/test-data.sql"
cat > "$testDataFile" << EOF
INSERT INTO books(title, author, rating, description)
VALUES ('The World as Will and Representation', 'Arthur Schopenhauer', 5, 'Abactor de camerarius sectam, amor accola!'),
       ('Mathematical Principles of Natural Philosophy', 'Isaac Newton', 5, 'Pol, dexter buxum!'),
       ('The Cosmic Connection', 'Carl Sagan', 4, 'Classiss sunt bubos de regius cannabis.'),
       ('The Count of Monte Cristo', 'Alexandre Dumas', 4, 'Barbatus clinias tandem apertos valebat est.'),
       ('Dialogue Concerning the Two Chief World Systems', 'Galileo Galilei', 4, 'Pol, a bene heuretes, talis domus!'),
       ('On the Revolutions of Heavenly Spheres', 'Nicolaus Copernicus', 2, 'Nocere hic ducunt ad regius zeta.'),
       ('Moral Letters to Lucilius', 'Lucius Seneca', 5, 'Advena dexter mineralis est.'),
       ('The Double Helix: A Personal Account of the Discovery of the Structure of DNA', 'James Watson', 4,
        'Danista manducares, tanquam velox usus.'),
       ('Relativity: The Special and General Theory', 'Albert Einstein', 3, 'A falsis, ausus peritus humani generis.'),
       ('Faust', 'Wolfgang Goethe', 4, 'Hibrida de velox rector, locus luna!');
EOF
printf "${STATUS_TAG} Default SQL initialization data has been added to ${ITALIC}test-data.sql${RESET_FORMAT}.\n"

  prodSchemaFile="$1/src/main/resources/sql/schema/prod-schema.sql"
cat > "$prodSchemaFile" << EOF
CREATE TABLE IF NOT EXISTS books
(
    id          BIGSERIAL PRIMARY KEY,
    title       VARCHAR(100)   NOT NULL,
    author      VARCHAR(100)   NOT NULL,
    rating      INT            NOT NULL,
    description VARCHAR(1000)  NOT NULL
);
EOF
printf "${STATUS_TAG} Default SQL initialization data has been added to ${ITALIC}prod-schema.sql${RESET_FORMAT}.\n"

  testSchemaFile="$1/src/main/resources/sql/schema/test-schema.sql"
cat > "$testSchemaFile" << EOF
DROP TABLE IF EXISTS books;

CREATE TABLE IF NOT EXISTS books
(
    id          BIGSERIAL PRIMARY KEY,
    title       VARCHAR(100)   NOT NULL,
    author      VARCHAR(100)   NOT NULL,
    rating      INT            NOT NULL,
    description VARCHAR(1000)  NOT NULL
);
EOF
printf "${STATUS_TAG} Default SQL initialization data has been added to ${ITALIC}test-schema.sql${RESET_FORMAT}.\n"
}

addStatisCodeAnalysisRules () {
  projectDirectory="$1"

  # PMD
  pmdRulesetFile="$projectDirectory/src/main/resources/static_code_analysis/pmd.xml"
  pmdRulesetHTTPResponse=$(curl --write-out "\n%{http_code}" --silent https://raw.githubusercontent.com/ciechanowiec/linux_mantra/master/resources/static_code_analysis/pmd.xml)
  pmdRulesetHTTPBody=$(echo "$pmdRulesetHTTPResponse" | sed '$d')
  pmdRulesetHTTPStatus=$(echo "$pmdRulesetHTTPResponse" | tail -n1)

  if [ "$pmdRulesetHTTPStatus" -eq 200 ]; then
      echo "$pmdRulesetHTTPBody" > "$pmdRulesetFile"
      printf "${STATUS_TAG} Default PMD rules have been added to ${ITALIC}pmd.xml${RESET_FORMAT}.\n"
  else
      printf "${ERROR_TAG} Unable to retrieve PMD rules. Execution aborted.\n"
      trash-put "$projectDirectory"
      exit 1
  fi

  # Checkstyle
  checkstyleRulesetFile="$projectDirectory/src/main/resources/static_code_analysis/checkstyle.xml"
  checkstyleRulesetHTTPResponse=$(curl --write-out "\n%{http_code}" --silent https://raw.githubusercontent.com/ciechanowiec/linux_mantra/master/resources/static_code_analysis/checkstyle.xml)
  checkstyleRulesetHTTPBody=$(echo "$checkstyleRulesetHTTPResponse" | sed '$d')
  checkstyleRulesetHTTPStatus=$(echo "$checkstyleRulesetHTTPResponse" | tail -n1)

  if [ "$checkstyleRulesetHTTPStatus" -eq 200 ]; then
      echo "$checkstyleRulesetHTTPBody" > "$checkstyleRulesetFile"
      printf "${STATUS_TAG} Default Checkstyle rules have been added to ${ITALIC}checkstyle.xml${RESET_FORMAT}.\n"
  else
      printf "${ERROR_TAG} Unable to retrieve Checkstyle rules. Execution aborted.\n"
      trash-put "$projectDirectory"
      exit 1
  fi

  # Spot Bugs
  sbExclusionsFile="$projectDirectory/src/main/resources/static_code_analysis/spotbugs-exclude.xml"
  sbExclusionsHTTPResponse=$(curl --write-out "\n%{http_code}" --silent https://raw.githubusercontent.com/ciechanowiec/linux_mantra/master/resources/static_code_analysis/spotbugs-exclude.xml)
  sbExclusionsHTTPBody=$(echo "$sbExclusionsHTTPResponse" | sed '$d')
  sbExclusionsHTTPStatus=$(echo "$sbExclusionsHTTPResponse" | tail -n1)

  if [ "$sbExclusionsHTTPStatus" -eq 200 ]; then
      echo "$sbExclusionsHTTPBody" > "$sbExclusionsFile"
      printf "${STATUS_TAG} Default Spot Bugs rules have been added to ${ITALIC}spotbugs-exclude.xml${RESET_FORMAT}.\n"
  else
      printf "${ERROR_TAG} Unable to retrieve Spot Bugs rules. Execution aborted.\n"
      trash-put "$projectDirectory"
      exit 1
  fi
}

insertContentToApplicationProperties () {
  applicationPropertiesFile="$1/src/main/resources/application.properties"
cat > "$applicationPropertiesFile" << EOF
server.port=\${PROGRAM_PORT:8080}
spring.main.banner-mode=off
spring.profiles.active=\${SPRING_ACTIVE_PROFILE:h2}
# To make 'th:method=...' work:
spring.mvc.hiddenmethod.filter.enabled=true

# LOGGING
logging.level.root=INFO
# Format like '2023-02-03 21:37:11.056 GMT+1':
logging.pattern.dateformat=yyyy-MM-dd HH:mm:ss.SSS O
logging.file.name=\${PROGRAM_LOGGING_FILE_ABS_PATH:./logs/application.log}
# Will roll the log file every day and add it name like 'application.log-2023-02-03_21-49.0'
# (docs: https://logback.qos.ch/manual/appenders.html):
logging.logback.rollingpolicy.file-name-pattern=\${LOG_FILE}-%d{yyyy-MM-dd}.%i
logging.logback.rollingpolicy.max-history=30
logging.logback.rollingpolicy.max-file-size=10MB
# No total size cap:
logging.logback.rollingpolicy.total-size-cap=0
# Restore from the comment the line below with an empty value to disable logging into the console:
# logging.pattern.console=

# DATA
spring.jpa.open-in-view=true
spring.jpa.hibernate.ddl-auto=none
spring.sql.init.mode=always
# Treat case literally and don't transform it:
spring.jpa.properties.hibernate.physical_naming_strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.datasource.username=\${POSTGRES_USER:admin}
spring.datasource.password=\${POSTGRES_PASSWORD:admin}

# ACTUATOR
# Enable all actuator endpoints over HTTP:
#management.endpoints.web.exposure.include=*
# Disable all actuator endpoints over HTTP:
management.endpoints.web.exposure.exclude=*
# Repeat the default base path for clarity:
management.endpoints.web.base-path=/actuator
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application.properties${RESET_FORMAT}.\n"
}

insertContentToApplicationH2Properties () {
  applicationPropertiesFile="$1/src/main/resources/application-h2.properties"
cat > "$applicationPropertiesFile" << EOF
# DATA
spring.datasource.url=jdbc:h2:mem:localdb
spring.sql.init.schema-locations=classpath:sql/schema/test-schema.sql
spring.sql.init.data-locations=classpath:sql/data/test-data.sql
spring.datasource.driver-class-name=org.h2.Driver
# H2 console will be available at '/h2-console':
spring.h2.console.enabled=true
# To enable h2 console when run in Docker
# (https://stackoverflow.com/questions/44867227/h2-console-throwing-a-error-weballowothers-in-h2-database):
spring.h2.console.settings.web-allow-others=true
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-h2.properties${RESET_FORMAT}.\n"
}

insertContentToApplicationProdProperties () {
  applicationPropertiesFile="$1/src/main/resources/application-prod.properties"
cat > "$applicationPropertiesFile" << EOF
# DATA
# 'postgres' is a database that exists by default:
spring.datasource.url=jdbc:postgresql://\${POSTGRES_HOSTNAME:localhost}:\${POSTGRES_PORT}/postgres
spring.sql.init.schema-locations=classpath:sql/schema/prod-schema.sql
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-prod.properties${RESET_FORMAT}.\n"
}

insertContentToApplicationTestProperties () {
  applicationPropertiesFile="$1/src/main/resources/application-test.properties"
cat > "$applicationPropertiesFile" << EOF
# DATA
# 'postgres' is a database that exists by default:
spring.datasource.url=jdbc:postgresql://\${POSTGRES_HOSTNAME:localhost}:\${POSTGRES_PORT}/postgres
spring.sql.init.schema-locations=classpath:sql/schema/test-schema.sql
spring.sql.init.data-locations=classpath:sql/data/test-data.sql
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-test.properties${RESET_FORMAT}.\n"
}

insertContentToTest () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  mainTestFile="$projectDirectory/src/test/java/$firstLevelPackageName/$secondLevelPackageName/$projectName/MainTest.java"
cat > "$mainTestFile" << EOF
package $firstLevelPackageName.$secondLevelPackageName.$projectName;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class MainTest {

    @Test
    void contextLoads() {
        int actualResult = 2 + 2;
        assertEquals(4, actualResult);
    }
}
EOF
printf "${STATUS_TAG} Default test content has been added to ${ITALIC}MainTest.java${RESET_FORMAT}.\n"

cat > "$projectDirectory/src/test/resources/application.properties" << EOF
logging.level.root=OFF
spring.main.banner-mode=off
EOF
printf "${STATUS_TAG} Default test application properties have been added to ${ITALIC}application.properties${RESET_FORMAT}.\n"

cat > "$projectDirectory/src/test/resources/logback-test.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/base.xml" />
    <logger name="org.springframework" level="OFF"/>
</configuration>
EOF
printf "${STATUS_TAG} Default test logging configuration has been added to ${ITALIC}logback-test.xml${RESET_FORMAT}.\n"

}

addEditorConfig () {
  projectDirectory=$1
  editorconfigFile="$projectDirectory/.editorconfig"
  touch "$editorconfigFile"
cat > "$editorconfigFile" << EOF
root = true

# EditorConfig helps maintain consistent coding styles for multiple
# developers working on the same project across various editors and IDEs.
# Docs: https://editorconfig.org/

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true
EOF
printf "${STATUS_TAG} ${ITALIC}.editorconfig${RESET_FORMAT} with default content has been created.\n"
}

addGitAttributes () {
  projectDirectory=$1
  gitattributesFile="$projectDirectory/.gitattributes"
  touch "$gitattributesFile"
cat > "$gitattributesFile" << EOF
# Set default behaviour to automatically normalize line endings:
* text=auto eol=lf
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
*.log*
*.logs*
logs
log
.idea
.vscode
target
node_modules
.DS_Store
# Compiled documentation:
README.html
README.pdf
EOF
printf "${STATUS_TAG} ${ITALIC}.gitignore${RESET_FORMAT} with default content has been created.\n"
}

addLicense () {
  projectDirectory=$1
  licenseFile="$projectDirectory/LICENSE.txt"
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
printf "${STATUS_TAG} ${ITALIC}LICENSE.txt${RESET_FORMAT} with default content has been created.\n"
}

addLombokConfig () {
  projectDirectory=$1
  lombokConfigFile="$projectDirectory/lombok.config"
cat > "$lombokConfigFile" << EOF
lombok.extern.findbugs.addSuppressFBWarnings = true
EOF
printf "${STATUS_TAG} ${ITALIC}lombok.config${RESET_FORMAT} with default content has been created.\n"
}

addPom () {
  projectDirectory=$1
  firstLevelPackageName=$2
  secondLevelPackageName=$3
  projectName=$4
  projectURL=$5
  pomFile="$projectDirectory/pom.xml"
  touch "$pomFile"
  latestSpringBootParentVersion=$(curl --silent https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-starter-parent/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
  latestConditionalLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/conditional/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
  latestSneakyFunLibVersion=$(curl --silent https://repo.maven.apache.org/maven2/eu/ciechanowiec/sneakyfun/maven-metadata.xml | grep '<latest>' | cut -d '>' -f 2 | cut -d '<' -f 1)
cat > "$pomFile" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>$latestSpringBootParentVersion</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <groupId>$firstLevelPackageName.$secondLevelPackageName</groupId>
    <artifactId>$projectName</artifactId>
    <version>1.0.0</version>

    <inceptionYear>$(date +%Y)</inceptionYear>

    <name>$projectName</name>
    <description>Java Program</description>
    <url>$projectURL</url>

    <properties>
        <!--  Building properties  -->
        <java.version>21</java.version>
        <fail-build-on-static-code-analysis-errors>true</fail-build-on-static-code-analysis-errors>
        <enforce-tests-coverage>true</enforce-tests-coverage>
        <!--  Dependencies  -->
        <im-aop-loggers.version>1.1.4</im-aop-loggers.version>
        <conditional.version>$latestConditionalLibVersion</conditional.version>
        <sneakyfun.version>$latestSneakyFunLibVersion</sneakyfun.version>
        <commons-lang3.version>3.17.0</commons-lang3.version>
        <spotbugs-annotations.version>4.8.6</spotbugs-annotations.version>
        <!-- Locking down Maven default plugins -->
        <maven-site-plugin.version>3.21.0</maven-site-plugin.version>
        <!-- Plugins -->
        <min.maven.version>3.8.6</min.maven.version>
        <maven-source-plugin.version>3.3.1</maven-source-plugin.version>
        <versions-maven-plugin.version>2.18.0</versions-maven-plugin.version>
        <maven-checkstyle-plugin.version>3.6.0</maven-checkstyle-plugin.version>
        <maven-pmd-plugin.version>3.26.0</maven-pmd-plugin.version>
        <spotbugs-maven-plugin.version>4.8.6.6</spotbugs-maven-plugin.version>
        <jacoco-maven-plugin.version>0.8.12</jacoco-maven-plugin.version>
        <jacoco-maven-plugin.coverage.minimum>0.8</jacoco-maven-plugin.coverage.minimum>
    </properties>

    <dependencies>
        <!-- ====================================================================== -->
        <!-- SPRING BOOT                                                            -->
        <!-- ====================================================================== -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <!-- ====================================================================== -->
        <!-- ETC                                                                    -->
        <!-- ====================================================================== -->
        <dependency>
            <groupId>eu.ciechanowiec</groupId>
            <artifactId>im-aop-loggers</artifactId>
            <version>\${im-aop-loggers.version}</version>
        </dependency>
        <dependency>
            <groupId>eu.ciechanowiec</groupId>
            <artifactId>conditional</artifactId>
            <version>\${conditional.version}</version>
        </dependency>
        <dependency>
            <groupId>eu.ciechanowiec</groupId>
            <artifactId>sneakyfun</artifactId>
            <version>\${sneakyfun.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>\${commons-lang3.version}</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
            <scope>provided</scope>
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
                <excludes>
                    <exclude>static_code_analysis/**</exclude>
                </excludes>
            </resource>
        </resources>

        <pluginManagement>
            <!-- Lock down plugins versions to avoid using Maven
                 defaults from the default Maven super-pom -->
            <plugins>
                <plugin>
                    <artifactId>maven-site-plugin</artifactId>
                    <version>\${maven-site-plugin.version}</version>
                </plugin>
            </plugins>
        </pluginManagement>

        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
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
                                        <include>README-docinfo.html</include>
                                        <include>README-docinfo-footer.html</include>
                                    </includes>
                                </resource>
                            </resources>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-dependency-plugin</artifactId>
                <executions>
                    <execution>
                        <id>analyze-dependencies</id>
                        <goals>
                            <goal>analyze</goal>
                        </goals>
                        <phase>package</phase>
                        <configuration>
                            <ignoreNonCompile>true</ignoreNonCompile>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
            <!-- Prevents from building if unit tests don't pass
                 and fails the build if there are no tests -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <configuration>
                    <failIfNoTests>\${enforce-tests-coverage}</failIfNoTests>
                </configuration>
            </plugin>
            <!-- Prevents from building if integration tests don't pass -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-failsafe-plugin</artifactId>
                <executions>
                    <execution>
                        <goals>
                            <goal>integration-test</goal>
                            <goal>verify</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-enforcer-plugin</artifactId>
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
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-source-plugin</artifactId>
                <version>\${maven-source-plugin.version}</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>jar-no-fork</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>versions-maven-plugin</artifactId>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>display-parent-updates</goal>
                            <goal>display-property-updates</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <ruleSet>
                        <ignoreVersions>
                            <ignoreVersion>
                                <!-- Ignoring milestone versions, like 3.0.4-M5 and 1.0.0-m23 -->
                                <type>regex</type>
                                <version>(?i)[0-9].+-m[0-9]+</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring alpha versions, like 5.0.0.Alpha2 and 12.0.0.alpha3 -->
                                <type>regex</type>
                                <version>(?i).*ALPHA.*</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring beta versions, like 5.0.0.Beta2 and 12.0.0.beta3 -->
                                <type>regex</type>
                                <version>(?i).*BETA.*</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring preview versions, like 12.1.0.jre11-preview -->
                                <type>regex</type>
                                <version>(?i).*PREVIEW.*</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring candidate release versions, like 6.2.0.CR2 -->
                                <type>regex</type>
                                <version>(?i)[0-9].+\.CR[0-9]+</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring release candidate versions, like 2.16.1-rc1 and 1.8.20-RC -->
                                <type>regex</type>
                                <version>(?i)[0-9].+-rc[0-9]*</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring develop versions, like 15.0.0.Dev01 -->
                                <type>regex</type>
                                <version>(?i)[0-9].+\.dev[0-9]*</version>
                            </ignoreVersion>
                            <ignoreVersion>
                                <!-- Ignoring ongoing build numbers, like 2.5.0-b34 and 2.5.0-B34 -->
                                <type>regex</type>
                                <version>(?i)[0-9].+-b[0-9]+</version>
                            </ignoreVersion>
                        </ignoreVersions>
                    </ruleSet>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-checkstyle-plugin</artifactId>
                <version>\${maven-checkstyle-plugin.version}</version>
                <configuration>
                    <configLocation>\${project.basedir}/src/main/resources/static_code_analysis/checkstyle.xml</configLocation>
                    <consoleOutput>true</consoleOutput>
                    <failsOnError>\${fail-build-on-static-code-analysis-errors}</failsOnError>
                    <linkXRef>false</linkXRef>
                    <includeTestSourceDirectory>true</includeTestSourceDirectory>
                </configuration>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>checkstyle</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-pmd-plugin</artifactId>
                <version>\${maven-pmd-plugin.version}</version>
                <configuration>
                    <rulesets>
                        <!-- For default rule sets see:
                             - https://github.com/pmd/pmd/tree/master/pmd-java/src/main/resources
                             - https://github.com/pmd/pmd/blob/master/pmd-core/src/main/resources/rulesets/internal/all-java.xml -->
                        <ruleset>\${project.basedir}/src/main/resources/static_code_analysis/pmd.xml</ruleset>
                    </rulesets>
                    <failOnViolation>\${fail-build-on-static-code-analysis-errors}</failOnViolation>
                    <verbose>true</verbose>
                    <includeTests>true</includeTests>
                    <linkXRef>false</linkXRef>
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
            <plugin>
                <groupId>com.github.spotbugs</groupId>
                <artifactId>spotbugs-maven-plugin</artifactId>
                <version>\${spotbugs-maven-plugin.version}</version>
                <configuration>
                    <excludeFilterFile>\${project.basedir}/src/main/resources/static_code_analysis/spotbugs-exclude.xml</excludeFilterFile>
                    <failOnError>\${fail-build-on-static-code-analysis-errors}</failOnError>
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
                            <haltOnFailure>\${enforce-tests-coverage}</haltOnFailure>
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
        </plugins>
    </build>

    <profiles>
        <profile>
            <id>fail-build-on-static-code-analysis-errors-when-no-tests</id>
            <activation>
                <property>
                    <name>skipTests</name>
                    <value>true</value>
                </property>
            </activation>
            <properties>
                <fail-build-on-static-code-analysis-errors>false</fail-build-on-static-code-analysis-errors>
            </properties>
        </profile>
        <profile>
            <id>enforce-tests-coverage-when-no-tests</id>
            <activation>
                <property>
                    <name>skipTests</name>
                    <value>true</value>
                </property>
            </activation>
            <properties>
                <enforce-tests-coverage>false</enforce-tests-coverage>
            </properties>
        </profile>
        <profile>
            <id>advanced-dependency-resolution</id>
            <activation>
                <!-- By default, this profile is active and is disabled when the property below is present  -->
                <property>
                    <name>!skipAdvancedDependencyResolution</name>
                </property>
            </activation>
            <build>
                <plugins>
                    <plugin>
                        <groupId>org.apache.maven.plugins</groupId>
                        <artifactId>maven-dependency-plugin</artifactId>
                        <executions>
                            <execution>
                                <id>download-sources</id>
                                <goals>
                                    <goal>resolve-sources</goal>
                                </goals>
                                <phase>validate</phase>
                                <configuration>
                                    <silent>true</silent>
                                </configuration>
                            </execution>
                            <execution>
                                <id>download-javadoc</id>
                                <goals>
                                    <goal>resolve</goal>
                                </goals>
                                <phase>validate</phase>
                                <configuration>
                                    <classifier>javadoc</classifier>
                                    <silent>true</silent>
                                </configuration>
                            </execution>
                        </executions>
                    </plugin>
                </plugins>
            </build>
        </profile>
    </profiles>
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
// Docinfo is used for foldable TOC.
// -> For full usage example see https://github.com/remkop/picocli
:docinfo: shared,private
:linkcss:
:stylesdir: https://www.ciechanowiec.eu/linux_mantra/
:stylesheet: adoc-css-style.css

This program was created on _${date}_ from a template.

== License
The program is subject to MIT No Attribution License

Copyright © $year $gitCommitterName $gitCommitterSurname

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so.

The Software is provided 'as is', without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the use or other dealings in the Software.
EOF
printf "${STATUS_TAG} ${ITALIC}README.adoc${RESET_FORMAT} file with default content has been created.\n"

readmeFileDocinfo="$1/README-docinfo.html"
cat > "$readmeFileDocinfo" << EOF
<!-- Foldable TOC -->
<style>
    #tocbot a.toc-link.node-name--H1{ font-style: italic }
    @media screen{
      #tocbot > ul.toc-list{ margin-bottom: 0.5em; margin-left: 0.125em }
      #tocbot ul.sectlevel0, #tocbot a.toc-link.node-name--H1 + ul{
        padding-left: 0 }
      #tocbot a.toc-link{ height:100% }
      .is-collapsible{ max-height:3000px; overflow:hidden; }
      .is-collapsed{ max-height:0 }
      .is-active-link{ font-weight:700 }
    }
    @media print{
      #tocbot a.toc-link.node-name--H4{ display:none }
    }
</style>
EOF
printf "${STATUS_TAG} ${ITALIC}README-docinfo.html${RESET_FORMAT} file with default content has been created.\n"

readmeFileDocinfoFooter="$1/README-docinfo-footer.html"
cat > "$readmeFileDocinfoFooter" << EOF
<script src="https://cdnjs.cloudflare.com/ajax/libs/tocbot/3.0.7/tocbot.min.js"></script>
<script>
    /* Tocbot dynamic TOC, works with tocbot 3.0.7 */
    var oldtoc = document.getElementById('toctitle').nextElementSibling;
    var newtoc = document.createElement('div');
    newtoc.setAttribute('id', 'tocbot');
    newtoc.setAttribute('class', 'js-toc');
    oldtoc.parentNode.replaceChild(newtoc, oldtoc);
    tocbot.init({ contentSelector: '#content',
        headingSelector: 'h1, h2, h3, h4, h5',
        smoothScroll: false,
        collapseDepth: 3 });
    var handleTocOnResize = function() {
        var width = window.innerWidth
                    || document.documentElement.clientWidth
                    || document.body.clientWidth;
        if (width < 768) {
            tocbot.refresh({ contentSelector: '#content',
                headingSelector: 'h1, h2, h3, h4',
                collapseDepth: 6,
                activeLinkClass: 'ignoreactive',
                throttleTimeout: 1000,
                smoothScroll: false });
        }
        else {
            tocbot.refresh({ contentSelector: '#content',
                headingSelector: 'h1, h2, h3, h4, h5',
                smoothScroll: false,
                collapseDepth: 3 });
        }
    };
    window.addEventListener('resize', handleTocOnResize);
    handleTocOnResize();
</script>
EOF
printf "${STATUS_TAG} ${ITALIC}README-docinfo-footer.html${RESET_FORMAT} file with default content has been created.\n"
}

addDocker () {
  projectDirectory=$1
  projectName=$2

cat > "$projectDirectory/.env" << EOF
COMPOSE_PARALLEL_LIMIT=1

PROGRAM_NAME=$projectName
PROGRAM_VERSION=1.0.0
PROGRAM_PORT=8080
PROGRAM_LOGGING_DIR=/var/logs/$projectName
PROGRAM_LOGGING_FILE_ABS_PATH=/var/logs/$projectName/application.log

SPRING_ACTIVE_PROFILE=h2

POSTGRES_HOSTNAME=postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
PGADMIN_DEFAULT_EMAIL=admin@admin.com
PGADMIN_DEFAULT_PASSWORD=admin
EOF
printf "${STATUS_TAG} ${ITALIC}.env${RESET_FORMAT} file with default content has been created.\n"

cat > "$projectDirectory/docker-compose.yml" << EOF
services:
  $projectName:
    build:
      dockerfile: Dockerfile
      args:
        PROGRAM_NAME: \${PROGRAM_NAME}
        PROGRAM_VERSION: \${PROGRAM_VERSION}
        PROGRAM_LOGGING_DIR: \${PROGRAM_LOGGING_DIR}
    environment:
      PROGRAM_NAME: \${PROGRAM_NAME}
      PROGRAM_VERSION: \${PROGRAM_VERSION}
      PROGRAM_PORT: \${PROGRAM_PORT}
      PROGRAM_LOGGING_DIR: \${PROGRAM_LOGGING_DIR}
      PROGRAM_LOGGING_FILE_ABS_PATH: \${PROGRAM_LOGGING_FILE_ABS_PATH}
      SPRING_ACTIVE_PROFILE: \${SPRING_ACTIVE_PROFILE}
      POSTGRES_HOSTNAME: \${POSTGRES_HOSTNAME}
      POSTGRES_PORT: \${POSTGRES_PORT}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    image: \${PROGRAM_NAME}:\${PROGRAM_VERSION}
    container_name: \${PROGRAM_NAME}
    volumes:
      - type: volume
        source: \${PROGRAM_NAME}-data
        target: \${PROGRAM_LOGGING_DIR}
    # exec is required in order to set the Java process as PID 1 inside the container, since Docker sends
    # termination signals only to PID 1, and we need those signals to be handled by the java process:
    entrypoint: [ "sh", "-c", "exec ./starter.sh" ]
    stop_grace_period: 300s
    hostname: \${PROGRAM_NAME}
    networks:
      - \${PROGRAM_NAME}-network
    ports:
      - target: \${PROGRAM_PORT}
        published: \${PROGRAM_PORT}
        protocol: tcp
        mode: host
    depends_on:
      - postgres

  postgres:
    image: postgres:latest
    container_name: postgres
    stop_grace_period: 300s
    init: true
    hostname: postgres
    command: ["postgres", "-c", "logging_collector=on", "-c", "log_directory=/var/log/postgresql", "-c", "log_statement=all"]
    networks:
      - \${PROGRAM_NAME}-network
    ports:
      - target: \${POSTGRES_PORT}
        published: \${POSTGRES_PORT}
        protocol: tcp
        mode: host
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - type: volume
        source: postgres-data
        target: /var/lib/postgresql/data
      - type: volume
        source: postgres-logs
        target: /var/log/postgresql

  pgadmin:
    build:
      context: .
      dockerfile: pgadmin/Dockerfile
      args:
        POSTGRES_USER: \${POSTGRES_USER}
        POSTGRES_PORT: \${POSTGRES_PORT}
    image: pgadmin
    container_name: pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: \${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: \${PGADMIN_DEFAULT_PASSWORD}
      PGADMIN_LISTEN_PORT: 5050
      PGADMIN_SERVER_JSON_FILE: /pgadmin4/servers.json
    networks:
      - \${PROGRAM_NAME}-network
    ports:
      - target: 5050
        published: 5050
        protocol: tcp
        mode: host
    depends_on:
      - postgres

volumes:
  $projectName-data:
    name: \${PROGRAM_NAME}-data
  postgres-data:
    name: postgres-data
  postgres-logs:
    name: postgres-logs

networks:
  $projectName-network:
    name: \${PROGRAM_NAME}-network
    driver: bridge
EOF
printf "${STATUS_TAG} ${ITALIC}docker-compose.yml${RESET_FORMAT} file with default content has been created.\n"

cat > "$projectDirectory/Dockerfile" << EOF
# First stage: Maven build
FROM maven:latest AS build

ARG PROGRAM_NAME
ARG PROGRAM_VERSION

WORKDIR /app

# Copy the Maven POM file and resolve dependencies
# This layer will be cached unless pom.xml changes
COPY pom.xml .
RUN mvn dependency:go-offline -DskipAdvancedDependencyResolution
RUN mvn dependency:resolve-plugins -DskipAdvancedDependencyResolution
RUN mvn dependency:analyze -DskipAdvancedDependencyResolution
RUN mvn versions:display-parent-updates -DskipAdvancedDependencyResolution
RUN mvn versions:display-property-updates -DskipAdvancedDependencyResolution

# Copy the rest of the project files
COPY .env .
COPY src ./src

# Build the application
RUN mvn clean package -DskipAdvancedDependencyResolution

# Second stage: Setup the Java runtime
FROM eclipse-temurin:21-jdk

ARG PROGRAM_NAME
ARG PROGRAM_VERSION
ARG PROGRAM_LOGGING_DIR

WORKDIR /app
# Copy only the built jar from the first stage
COPY --from=build /app/target/\$PROGRAM_NAME-\$PROGRAM_VERSION.jar /app
# exec is required in order to set the Java process as PID 1 inside the container, since Docker sends
# termination signals only to PID 1, and we need those signals to be handled by the java process:
RUN printf '#!/bin/bash\n\nexec java -jar \$PROGRAM_NAME-\$PROGRAM_VERSION.jar\n\ntail -f /dev/null\n' > starter.sh
RUN chmod 755 starter.sh

VOLUME \$PROGRAM_LOGGING_DIR
EOF
printf "${STATUS_TAG} ${ITALIC}Dockerfile${RESET_FORMAT} file with default content has been created.\n"
}

addPgadmin () {
  projectDirectory=$1

mkdir -p "$projectDirectory/pgadmin"

cat > "$projectDirectory/pgadmin/Dockerfile" << EOF
FROM dpage/pgadmin4:latest

USER root

ARG POSTGRES_USER
ARG POSTGRES_PORT

COPY ../pgadmin/servers.json /pgadmin4/servers.json

RUN sed -i "s/POSTGRES_USER/"\${POSTGRES_USER}"/g" /pgadmin4/servers.json
RUN sed -i "s/POSTGRES_PORT/"\${POSTGRES_PORT}"/g" /pgadmin4/servers.json
EOF
printf "${STATUS_TAG} ${ITALIC}pgadmin/Dockerfile${RESET_FORMAT} file with default content has been created.\n"

cat > "$projectDirectory/pgadmin/servers.json" << EOF
{
  "Servers": {
    "1": {
      "Name": "Basic",
      "Group": "Servers",
      "Port": POSTGRES_PORT,
      "Username": "POSTGRES_USER",
      "Host": "postgres",
      "MaintenanceDB": "postgres"
    }
  }
}
EOF
printf "${STATUS_TAG} ${ITALIC}pgadmin/servers.json${RESET_FORMAT} file with default content has been created.\n"

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
	printf "${STATUS_TAG} Git committer for this project has been set up: $gitCommitterName $gitCommitterSurname <$gitCommitterEmail>.\n"
	cd "$currentDirectory" || exit 1
}

initCommit() {
	projectDirectory=$1
  cd "$projectDirectory" || exit 1
  git add . > /dev/null 2>&1
  git commit -m "Init commit" > /dev/null 2>&1
	printf "${STATUS_TAG} Git init commit was made.\n"
}

showFinishMessage () {
	projectName=$1
	printf "${BOLD_LIGHT_GREEN}[SUCCESS]:${RESET_FORMAT} The project ${ITALIC}$projectName${RESET_FORMAT} with the following file structure has been created:\n"
  tree --dirsfirst -a "$projectDirectory"
}

openProjectInIDE () {
  projectDirectory=$1
  launcherPath=""

  linesWithLinuxReleaseName=0
  linesWithMacReleaseName=0
  if compgen -G "/etc/*-release" > /dev/null; # Checking a file existence with a glob pattern: https://stackoverflow.com/a/34195247
      then
        linesWithLinuxReleaseName=$(cat /etc/*-release | grep --ignore-case --count "$expectedLinuxReleaseName")
    elif [ "$(command system_profiler -v &> /dev/null ; echo $?)" -eq 1 ]
      then
        linesWithMacReleaseName=$(system_profiler SPSoftwareDataType | grep --ignore-case --count "$expectedMacReleaseName") # https://www.cyberciti.biz/faq/mac-osx-find-tell-operating-system-version-from-bash-prompt/
  fi
  if [ "$linesWithLinuxReleaseName" -gt 0 ] && [ "$linesWithMacReleaseName" -gt 0 ];
    then
      echo "Unexpected state: both supported operating systems detected, i.e. Mac and Linux. Exiting..."
      exit 1
    elif [ "$linesWithLinuxReleaseName" -gt 0 ];
      then
        # launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"
        launcherPath="/snap/intellij-idea-community/current/bin/idea.sh"
    elif [ "$linesWithMacReleaseName" -gt 0 ];
      then
        launcherPath="/opt/homebrew/bin/idea-ce"
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  printf "${BOLD_LIGHT_YELLOW}[IntelliJ IDEA]:${RESET_FORMAT} Opening the project...\n"
  if [ ! -f "$launcherPath" ]
    then
      printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
      exit 1
    else
      nohup "$launcherPath" nosplash "$projectDirectory" > /dev/null 2>&1 &
  fi
}

# ============================================== #
#                                                #
#              CONFIGURATION BLOCK               #
#                                                #
# ============================================== #

# Revise and change values of the variables below to meet your needs
expectedLinuxReleaseName="jammy"
expectedMacReleaseName="macOS 15"
gitCommitterName="Herman"
gitCommitterSurname="Ciechanowiec"
gitCommitterEmail="herman@ciechanowiec.eu"
firstLevelPackageName="eu"
secondLevelPackageName="ciechanowiec"
projectURL="https://ciechanowiec.eu/"
pathUntilProjectDirectory="${HOME}/0_prog" # This directory must exist when script is executed

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
addStatisCodeAnalysisRules "$projectDirectory"
insertContentToApplicationProperties "$projectDirectory"
insertContentToApplicationH2Properties "$projectDirectory"
insertContentToApplicationProdProperties "$projectDirectory"
insertContentToApplicationTestProperties  "$projectDirectory"
insertContentToSQLInitFiles "$projectDirectory"
insertContentToTest "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"

# Pollute root directory with additional files:
addEditorConfig "$projectDirectory"
addGitAttributes "$projectDirectory"
addGitignore "$projectDirectory"
addLicense "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname"
addLombokConfig "$projectDirectory"
addPom "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName" "$projectURL"
addReadme "$projectDirectory" "$projectName" "$gitCommitterName" "$gitCommitterSurname" "$gitCommitterEmail"
addDocker "$projectDirectory" "$projectName"
addPgadmin "$projectDirectory"

# Setup git:
initGit "$projectDirectory"
setupGitCommitter "$projectDirectory" "$gitCommitterName" "$gitCommitterSurname" "$gitCommitterEmail"
initCommit "$projectDirectory"

# Finish:
showFinishMessage "$projectName"
openProjectInIDE "$projectDirectory"
