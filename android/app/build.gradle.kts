plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vacmaster.vacmaster"
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
        applicationId = "com.vacmaster.vacmaster"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    androidResources {
        // 项目里有 ~7400 张 webp + ~7400 个 mp3（合计约 830MB），
        // 这些格式本身已是压缩态，AGP 再 deflate 一遍几乎省不下字节
        // （实测 <2%），却要为 800MB 数据做一遍 CPU 密集的压缩，
        // 把 assembleRelease 拖到 90 分钟都跑不完。
        // 显式声明不压缩：构建时间大幅下降，运行时还能 mmap 直读，加载更快。
        noCompress.addAll(
            listOf(
                "webp", "png", "jpg", "jpeg", "gif",
                "mp3", "ogg", "m4a", "aac", "opus", "flac", "wav",
            ),
        )
    }
}

flutter {
    source = "../.."
}
