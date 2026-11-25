import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun selectedMosigameBackend(): String {
    val defines = project.findProperty("dart-defines")?.toString().orEmpty()
    val backend = defines
        .split(',')
        .asSequence()
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .firstOrNull { it.startsWith("MOSIGAME_BACKEND=") }
        ?.substringAfter('=')
        ?: "server"
    require(backend in setOf("server", "test", "local")) {
        "MOSIGAME_BACKEND must be server, test or local."
    }
    return backend
}

val mosigameBackend = selectedMosigameBackend()
val nativeFirebaseConfig = if (mosigameBackend == "server") {
    file("firebase/server/google-services.json")
} else {
    // local mode does not use FCM, but a valid TEST default app keeps native
    // Firebase providers from falling back to production before Dart starts.
    file("firebase/test/google-services.json")
}
logger.lifecycle("Mosigame Android Firebase native backend: $mosigameBackend")

// The Google Services task creates resources used by FirebaseInitProvider and
// background FCM before Dart starts. Override its input with the same backend
// selected by the Flutter build instead of relying on one fixed root JSON.
afterEvaluate {
    tasks.withType<com.google.gms.googleservices.GoogleServicesTask>().configureEach {
        googleServicesJsonFiles.set(listOf(nativeFirebaseConfig))
    }
}

//=======================릴리즈 서명 키==============================
// 업로드 keystore의 경로·비밀번호는 저장소에 커밋하지 않고 android/key.properties
// (.gitignore 대상)에 둡니다. 파일이 없으면 debug 키로 서명해 로컬 릴리즈 실행은
// 계속 되지만, 그 산출물은 스토어에 올릴 수 없습니다.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.warmhandongne.msg"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // iOS 번들 ID와 동일하게 맞춥니다. 첫 스토어 업로드 후에는 변경할 수 없습니다.
        applicationId = "com.warmhandongne.msg"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // key.properties가 없는 환경(신규 클론 등)에서도 빌드는 되게 둡니다.
                signingConfigs.getByName("debug")
            }
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
