import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json and wires the Firebase/Google OAuth client config into the build.
    id("com.google.gms.google-services")
}

// Google Maps key for Android (Module 6), from the gitignored frontend/dart_defines.json
// that `flutter run --dart-define-from-file=dart_defines.json` also reads. Empty → the
// app shows its preview map instead of Google Maps.
val mapsApiKey: String = rootProject.file("../dart_defines.json").let { file ->
    if (!file.exists()) return@let ""
    val keys = JsonSlurper().parse(file) as Map<*, *>
    (keys["MAPS_API_KEY_ANDROID"] as? String).orEmpty()
}

android {
    namespace = "com.khojlo.khojlo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.khojlo.khojlo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
