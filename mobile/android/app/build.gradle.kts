import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val playPropertiesFile = rootProject.file("play.properties")
val playProperties = Properties().apply {
    if (playPropertiesFile.exists()) {
        playPropertiesFile.inputStream().use { load(it) }
    }
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

val playApplicationId =
    providers.gradleProperty("KELIMIO_ANDROID_APPLICATION_ID").orNull
        ?: playProperties.getProperty("applicationId")
        ?: "com.kelimio.app"
val playAppLabel =
    providers.gradleProperty("KELIMIO_ANDROID_APP_LABEL").orNull
        ?: playProperties.getProperty("appLabel")
        ?: "Kelimio"
val productionRedirectScheme =
    providers.gradleProperty("KELIMIO_ANDROID_REDIRECT_SCHEME").orNull
        ?: playProperties.getProperty("redirectScheme")
        ?: "com.kelimio.app"

require(Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$").matches(playApplicationId)) {
    "Android applicationId must be a lower-case reverse-domain identifier."
}
require(Regex("^[a-z][a-z0-9+.-]*$").matches(productionRedirectScheme)) {
    "Android OIDC redirect scheme is invalid."
}

val releaseSigningConfigured =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .all { !keyProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.kelimio.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = playApplicationId
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appAuthRedirectScheme"] = productionRedirectScheme
        manifestPlaceholders["appLabel"] = playAppLabel
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("production") {
            dimension = "environment"
        }
        create("smoke") {
            dimension = "environment"
            applicationIdSuffix = ".smoke"
            versionNameSuffix = "-smoke"
            manifestPlaceholders["appAuthRedirectScheme"] = "com.kelimio.app.smoke"
            manifestPlaceholders["appLabel"] = "Kelimio Smoke"
        }
        create("e2e") {
            dimension = "environment"
            applicationIdSuffix = ".e2e"
            versionNameSuffix = "-e2e"
            manifestPlaceholders["appAuthRedirectScheme"] = "com.kelimio.app.e2e"
            manifestPlaceholders["appLabel"] = "Kelimio E2E"
        }
    }
}

tasks.matching { it.name == "bundleProductionRelease" }.configureEach {
    doFirst {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Production release signing is not configured. " +
                    "Create mobile/android/key.properties from key.properties.example.",
            )
        }
        if (playApplicationId == "com.kelimio.app") {
            throw GradleException(
                "The scaffold applicationId com.kelimio.app cannot be uploaded to Google Play. " +
                    "Create mobile/android/play.properties with the approved immutable applicationId.",
            )
        }
    }
}

flutter {
    source = "../.."
}
