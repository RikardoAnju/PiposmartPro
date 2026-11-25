import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Tambahkan baris ini untuk mengaktifkan Google Services
    id("com.google.gms.google-services")
    // Flutter Gradle Plugin harus diletakkan setelah plugin Android dan Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val debugKeystoreProperties = Properties()
val debugKeystorePropertiesFile = rootProject.file("debug.properties")
val hasDebugKeystore = debugKeystorePropertiesFile.exists()
if (hasDebugKeystore) {
    debugKeystorePropertiesFile.inputStream().use { debugKeystoreProperties.load(it) }
}

android {
    namespace = "id.piposmart.pro.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
}
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID harus sesuai dengan yang didaftarkan di Firebase Console
        applicationId = "id.piposmart.pro.apps"
        
        minSdk = flutter.minSdkVersion
        // Wajib Android 16 (API 36) per kebijakan Play Store (deadline 31 Agu 2026).
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Piposmart Pro Dev")
            manifestPlaceholders["appLabel"] = "Piposmart Pro Dev"
        }

        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Piposmart Pro")
            manifestPlaceholders["appLabel"] = "Ayo Cuci"
        }
    }

    signingConfigs {
        create("ayocuciDebug") {
            if (hasDebugKeystore) {
                keyAlias = debugKeystoreProperties.getProperty("keyAlias")
                keyPassword = debugKeystoreProperties.getProperty("keyPassword")
                storeFile = file(debugKeystoreProperties.getProperty("storeFile"))
                storePassword = debugKeystoreProperties.getProperty("storePassword")
            }
        }

        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            if (hasDebugKeystore) {
                signingConfig = signingConfigs.getByName("ayocuciDebug")
            }
        }

        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            // Include stripped native symbol tables in BUNDLE-METADATA. Flutter
            // verifies this before accepting a release AAB, and Play Console
            // can use the symbols to deobfuscate native crash reports.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}


dependencies {

    implementation("androidx.multidex:multidex:2.0.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

}
