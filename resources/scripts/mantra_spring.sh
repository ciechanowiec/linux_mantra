#!/bin/bash
# A. Script for generating Spring Boot projects from a template.
#    The template is based on the output of the following command:
#    spring init --dependencies=web,actuator,devtools,validation,data-jpa,mysql,h2,lombok \
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
	if ! command tree -v &> /dev/null
	then
		printf "${ERROR_TAG} 'tree' package which is required to run the script hasn't been detected. The script execution has been aborted.\n"
    exit
	fi
}

verifyIfGitExists () {
	if ! command git --version &> /dev/null
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
	mkdir -p "$projectDirectory"/src/{main/{java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName"/{controller,model,repository,service},resources},test/java/"$firstLevelPackageName"/"$secondLevelPackageName"/"$projectName"}
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
@SuppressWarnings("JpaDataSourceORMInspection")
public class Book {

    @Id
    @Column(name = "id")
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @SuppressWarnings({"unused", "InstanceVariableMayNotBeInitialized"})
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
    id          INT            NOT NULL AUTO_INCREMENT,
    title       VARCHAR(100)   NOT NULL,
    author      VARCHAR(100)   NOT NULL,
    rating      INT            NOT NULL,
    description VARCHAR(1000)  NOT NULL,
    PRIMARY KEY (id)
);
EOF
printf "${STATUS_TAG} Default SQL initialization data has been added to ${ITALIC}prod-schema.sql${RESET_FORMAT}.\n"

  testSchemaFile="$1/src/main/resources/sql/schema/test-schema.sql"
cat > "$testSchemaFile" << EOF
DROP TABLE IF EXISTS books;

CREATE TABLE IF NOT EXISTS books
(
    id          INT            NOT NULL AUTO_INCREMENT,
    title       VARCHAR(100)   NOT NULL,
    author      VARCHAR(100)   NOT NULL,
    rating      INT            NOT NULL,
    description VARCHAR(1000)  NOT NULL,
    PRIMARY KEY (id)
);
EOF
printf "${STATUS_TAG} Default SQL initialization data has been added to ${ITALIC}test-schema.sql${RESET_FORMAT}.\n"
}

insertContentToApplicationProperties () {
  applicationPropertiesFile="$1/src/main/resources/application.properties"
cat > "$applicationPropertiesFile" << EOF
server.port=8080
spring.main.banner-mode=off
spring.profiles.active=h2
# To make 'th:method=...' work:
spring.mvc.hiddenmethod.filter.enabled=true

# LOGGING
logging.level.root=INFO
# Format like '2023-02-03 21:37:11.056 GMT+1':
logging.pattern.dateformat=yyyy-MM-dd HH:mm:ss.SSS O
logging.file.name=./logs/application.log
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
# Treat case literally and don't transform it:
spring.jpa.properties.hibernate.physical_naming_strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl

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
spring.devtools.livereload.enabled=true

# DATA
spring.datasource.url=jdbc:h2:mem:localdb
spring.jpa.hibernate.ddl-auto=none
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:sql/schema/test-schema.sql
spring.sql.init.data-locations=classpath:sql/data/test-data.sql
# To not initialize the database on start, replace
# the 4 lines above with the 2 following lines:
#spring.jpa.hibernate.ddl-auto=create-drop
#spring.sql.init.mode=never
logging.level.org.hibernate=TRACE
# H2 console will be available at '/h2-console':
spring.h2.console.enabled=true
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.username=admin
spring.datasource.password=admin
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-h2.properties${RESET_FORMAT}.\n"
}

insertContentToApplicationProdProperties () {
  applicationPropertiesFile="$1/src/main/resources/application-prod.properties"
cat > "$applicationPropertiesFile" << EOF
# DATA
spring.datasource.url=jdbc:mysql://localhost:3306/bookshop?createDatabaseIfNotExist=true
spring.jpa.hibernate.ddl-auto=none
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:sql/schema/prod-schema.sql
# To not initialize the database on start, replace
# the 3 lines above with the 2 following lines:
#spring.jpa.hibernate.ddl-auto=create-drop
#spring.sql.init.mode=never
spring.datasource.username=root
spring.datasource.password=password
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-prod.properties${RESET_FORMAT}.\n"
}

insertContentToApplicationUATProperties () {
  applicationPropertiesFile="$1/src/main/resources/application-uat.properties"
cat > "$applicationPropertiesFile" << EOF
# DATA
spring.datasource.url=jdbc:mysql://localhost:3306/university-uat?createDatabaseIfNotExist=true
spring.jpa.hibernate.ddl-auto=none
spring.sql.init.mode=always
spring.sql.init.schema-locations=classpath:sql/schema/test-schema.sql
spring.sql.init.data-locations=classpath:sql/data/test-data.sql
spring.datasource.username=root
spring.datasource.password=password
EOF
printf "${STATUS_TAG} Default application properties have been added to ${ITALIC}application-uat.properties${RESET_FORMAT}.\n"
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
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class MainTest {

    @Test
    void contextLoads() {
        assertTrue(true);
    }
}
EOF
printf "${STATUS_TAG} Default test content has been added to ${ITALIC}MainTest.java${RESET_FORMAT}.\n"
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
###############################
#        Line Endings         #
###############################

# Set default behaviour to automatically normalize line endings:
* text=auto eol=lf

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
printf "${STATUS_TAG} ${ITALIC}LICENSE.txt${RESET_FORMAT} with default content has been created.\n"
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
    <java.version>17</java.version>
    <!--  Dependencies  -->
    <conditional.version>$latestConditionalLibVersion</conditional.version>
    <sneakyfun.version>$latestSneakyFunLibVersion</sneakyfun.version>
    <commons-lang3.version>3.13.0</commons-lang3.version>
    <jsr305.version>3.0.2</jsr305.version>
    <spotbugs-annotations.version>4.7.3</spotbugs-annotations.version>
    <!-- Locking down Maven default plugins -->
    <maven-site-plugin.version>3.12.1</maven-site-plugin.version>
    <!-- Plugins -->
    <min.maven.version>3.8.6</min.maven.version>
    <versions-maven-plugin.version>2.16.0</versions-maven-plugin.version>
    <jacoco-maven-plugin.version>0.8.10</jacoco-maven-plugin.version>
    <jacoco-maven-plugin.coverage.minimum>0</jacoco-maven-plugin.coverage.minimum>
    <spotbugs-maven-plugin.version>4.7.3.5</spotbugs-maven-plugin.version>
  </properties>

  <dependencies>
    <!-- Spring Boot -->
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
      <artifactId>spring-boot-devtools</artifactId>
      <scope>runtime</scope>
      <optional>true</optional>
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
      <groupId>com.mysql</groupId>
      <artifactId>mysql-connector-j</artifactId>
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
    <!-- Utils -->
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
      <!--  Mainly for @CheckForNull and @Nonnull annotations.
            Google groupId is used, because the native groupId isn't
            available at repo.maven.apache.org/maven2 -->
      <groupId>com.google.code.findbugs</groupId>
      <artifactId>jsr305</artifactId>
      <version>\${jsr305.version}</version>
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
      <!-- Spring Boot support in Apache Maven -->
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
                    <include>README-docinfo.html</include>
                    <include>README-docinfo-footer.html</include>
                  </includes>
                </resource>
              </resources>
            </configuration>
          </execution>
        </executions>
      </plugin>
      <!-- Reports on unused dependencies: -->
      <plugin>
          <groupId>org.apache.maven.plugins</groupId>
          <artifactId>maven-dependency-plugin</artifactId>
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
        <configuration>
          <failIfNoTests>true</failIfNoTests>
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
      <!-- Requires new Maven version -->
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
      <!-- Reports on possible updates of dependencies and plugins -->
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>versions-maven-plugin</artifactId>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>display-dependency-updates</goal>
              <goal>display-plugin-updates</goal>
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
                <!-- Ignoring alpha versions, like 5.0.0.Beta2 and 12.0.0.beta3 -->
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
                <version>(?i)[0-9].+\\.CR[0-9]+</version>
              </ignoreVersion>
              <ignoreVersion>
                <!-- Ignoring release candidate versions, like 2.15.0-rc1 and 1.8.20-RC -->
                <type>regex</type>
                <version>(?i)[0-9].+-rc[0-9]*</version>
              </ignoreVersion>
              <ignoreVersion>
                <!-- Ignoring develop versions, like 15.0.0.Dev01 -->
                <type>regex</type>
                <version>(?i)[0-9].+\\.dev[0-9]*</version>
              </ignoreVersion>
            </ignoreVersions>
          </ruleSet>
        </configuration>
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

showFinishMessage () {
	projectName=$1
	printf "${BOLD_LIGHT_GREEN}[SUCCESS]:${RESET_FORMAT} The project ${ITALIC}$projectName${RESET_FORMAT} with the following file structure has been created:\n"
  tree --dirsfirst -a "$projectDirectory"
}

openProjectInIDE () {
  launcherPathLinux=$1
  launcherPathMac=$2
  projectDirectory=$3
  launcherPath=""

  isMacOS=false
  isLinux=false
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
        isLinux=true
        launcherPath="$launcherPathLinux"
    elif [ "$linesWithMacReleaseName" -gt 0 ];
      then
        isMacOS=true
        launcherPath="$launcherPathMac"
    else
      echo "Unsupported operating system. Exiting..."
      exit 1;
  fi

  printf "${BOLD_LIGHT_YELLOW}[IntelliJ IDEA]:${RESET_FORMAT} Opening the project...\n"
  if [ "$isLinux" == true ] && [ "$isMacOS" == false ];
    then
        if [ ! -f "$launcherPath" ]
          then
            printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
            exit 1
          else
            nohup "$launcherPathLinux" nosplash "$projectDirectory" > /dev/null 2>&1 &
        fi
    elif [ "$isMacOS" == true ] && [ "$isLinux" == false ];
      then
        if [ ! -d "$launcherPath" ]
          then
            printf "${ERROR_TAG} The IntelliJ IDEA launcher ${ITALIC}${launcherPath}${RESET_FORMAT} hasn't been detected. Opening will be aborted.\n"
            exit 1
          else
            open -na "IntelliJ IDEA.app" --args "$projectDirectory" nosplash
        fi
    else
      echo "Unexpected error occurred. Launching failed"
      exit 1
  fi
}

# ============================================== #
#                                                #
#              CONFIGURATION BLOCK               #
#                                                #
# ============================================== #

# Revise and change values of the variables below to meet your needs
expectedLinuxReleaseName="jammy"
expectedMacReleaseName="macOS 13"
gitCommitterName="Herman"
gitCommitterSurname="Ciechanowiec"
gitCommitterEmail="herman@ciechanowiec.eu"
firstLevelPackageName="eu"
secondLevelPackageName="ciechanowiec"
projectURL="https://ciechanowiec.eu/"
pathUntilProjectDirectory="${HOME}/0_prog" # This directory must exist when script is executed
# It is assumed that the project will be opened in IntelliJ IDEA Ultimate.
# In case you want to use IntelliJ IDEA Community, comment out the code line below
# and restore from the comment the next line:
launcherPathLinux="/snap/intellij-idea-ultimate/current/bin/idea.sh"
#launcherPathLinux="/snap/intellij-idea-community/current/bin/idea.sh"
launcherPathMac="$HOME/Applications/IntelliJ IDEA.app"

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
insertContentToMainTest "$projectDirectory" "$firstLevelPackageName" "$secondLevelPackageName" "$projectName"
insertContentToApplicationProperties "$projectDirectory"
insertContentToApplicationH2Properties "$projectDirectory"
insertContentToApplicationProdProperties "$projectDirectory"
insertContentToApplicationUATProperties  "$projectDirectory"
insertContentToSQLInitFiles "$projectDirectory"

# Pollute root directory with additional files:
addEditorConfig "$projectDirectory"
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
openProjectInIDE "$launcherPathLinux" "$launcherPathMac" "$projectDirectory"
