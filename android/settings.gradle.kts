pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localProperties = file("local.properties")
        require(localProperties.exists()) { "Install Flutter and run flutter pub get to create android/local.properties." }
        localProperties.inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk") ?: error("flutter.sdk missing from android/local.properties")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
