import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"
    kotlin("jvm") version "2.4.10"
    kotlin("plugin.spring") version "2.4.10"
}

group = "com.kelimio"
version = "0.1.0-SNAPSHOT"

// Spring Boot 3.5.16 manages 5.3.6, which is below the fixes for
// CVE-2026-54399 and CVE-2026-54428. Keep the compatible security floor
// explicit until the Boot 3.x BOM carries an equal or newer release.
extra["httpcore5.version"] = "5.4.3"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    implementation(platform("software.amazon.awssdk:bom:2.50.2"))
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-jooq")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("io.micrometer:micrometer-registry-prometheus")
    implementation("org.apache.commons:commons-compress:1.28.0")
    implementation("org.apache.poi:poi-ooxml:5.5.1")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("software.amazon.awssdk:s3")
    implementation("software.amazon.awssdk:cognitoidentityprovider")
    implementation("software.amazon.awssdk:sqs")
    implementation("software.amazon.awssdk:ssm")
    implementation("software.amazon.awssdk:url-connection-client")

    runtimeOnly("org.postgresql:postgresql:42.7.12")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
}

configurations.configureEach {
    // Every AWS SDK client is wired to UrlConnectionHttpClient explicitly.
    // Keep the unused async Netty implementation out of the runtime image.
    exclude(group = "software.amazon.awssdk", module = "netty-nio-client")
}

dependencyLocking {
    lockAllConfigurations()
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_21
        freeCompilerArgs.add("-Xjsr305=strict")
        javaParameters = true
    }
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        allWarningsAsErrors = true
    }
}
