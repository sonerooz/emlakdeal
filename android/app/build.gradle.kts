import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val anahtarDosyasi = rootProject.file("key.properties")
val anahtarOzellikleri = Properties().apply {
    if (anahtarDosyasi.exists()) anahtarDosyasi.inputStream().use { load(it) }
}

android {
    namespace = "com.soner.emlakdeal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.soner.emlakdeal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (anahtarDosyasi.exists()) {
                keyAlias = anahtarOzellikleri.getProperty("keyAlias")
                keyPassword = anahtarOzellikleri.getProperty("keyPassword")
                storeFile = rootProject.file(anahtarOzellikleri.getProperty("storeFile"))
                storePassword = anahtarOzellikleri.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Market derlemesi upload anahtarıyla imzalanır. Anahtar yoksa derleme durur; yalnız
            // EMLAKDEAL_DEBUG_IMZA=1 verilirse (telefona test kurulumu) debug anahtarıyla imzalanır.
            signingConfig = when {
                anahtarDosyasi.exists() && System.getenv("EMLAKDEAL_DEBUG_IMZA") != "1" -> signingConfigs.getByName("release")
                System.getenv("EMLAKDEAL_DEBUG_IMZA") == "1" -> signingConfigs.getByName("debug")
                else -> throw GradleException("android/key.properties yok: market derlemesi imzalanamaz (test için EMLAKDEAL_DEBUG_IMZA=1)")
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
