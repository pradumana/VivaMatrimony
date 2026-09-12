import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load key.properties (local dev). CI/CD uses env vars instead.
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyPropsFile.inputStream().use { keyProps.load(it) }
}

fun signingProp(envVar: String, propKey: String): String =
    System.getenv(envVar) ?: keyProps.getProperty(propKey)
    ?: error("Missing signing config: set $envVar env var or $propKey in key.properties")

android {
    namespace = "com.vivamatrimony.viva_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            storeFile     = file(signingProp("KEYSTORE_PATH",     "storeFile"))
            storePassword = signingProp("KEYSTORE_PASSWORD", "storePassword")
            keyAlias      = signingProp("KEY_ALIAS",         "keyAlias")
            keyPassword   = signingProp("KEY_PASSWORD",      "keyPassword")
        }
    }

    defaultConfig {
        applicationId = "com.vivamatrimony.viva_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
