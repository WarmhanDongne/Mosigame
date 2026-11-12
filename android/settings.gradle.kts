pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localProperties = file("local.properties")
            // Flutter writes local.properties as UTF-8. Reading it through
            // Properties.load(InputStream) treats non-ASCII SDK paths as
            // ISO-8859-1 and breaks Gradle on localized macOS user folders.
            localProperties.reader(Charsets.UTF_8).use {
                properties.load(it)
            }
            // Flutter's bundled plugin loader reads this same file through the
            // legacy byte-stream API. Re-serializing after the UTF-8 read
            // writes Java's portable \\u escapes, so both readers resolve the
            // identical SDK path. local.properties is machine-local/ignored.
            localProperties.outputStream().use { properties.store(it, null) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
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
    id("com.android.application") version "9.0.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.1") apply false
    // 크래시 리포트에 사람이 읽을 수 있는 위치가 나오게 심볼을 올려 줍니다.
    id("com.google.firebase.crashlytics") version("3.0.2") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
