plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

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
        applicationId = "com.kelimio.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appAuthRedirectScheme"] = "com.kelimio.app"
        manifestPlaceholders["appLabel"] = "Kelimio"
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

flutter {
    source = "../.."
}
