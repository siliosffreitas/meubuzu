import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Lê a chave do Google Maps de um arquivo .env simples (CHAVE=valor).
fun readDotEnv(file: File): Properties = Properties().apply {
    if (file.exists()) {
        file.forEachLine { line ->
            val trimmed = line.trim()
            if (trimmed.isNotEmpty() && !trimmed.startsWith("#") && trimmed.contains('=')) {
                val separator = trimmed.indexOf('=')
                val key = trimmed.substring(0, separator).trim()
                val value = trimmed.substring(separator + 1).trim().removeSurrounding("\"")
                setProperty(key, value)
            }
        }
    }
}

// Precedência: .env do app (chave específica do Android), android/local.properties
// e, por fim, variáveis de ambiente. Nenhum desses arquivos é versionado.
val dotEnv = readDotEnv(rootProject.file("../.env"))
val localProperties = readDotEnv(rootProject.file("local.properties"))
val mapsApiKey: String =
    dotEnv.getProperty("MAPS_API_KEY_ANDROID")
        ?: dotEnv.getProperty("MAPS_API_KEY")
        ?: localProperties.getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY_ANDROID")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

android {
    namespace = "br.com.meubuzu.meubuzu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.meubuzu.meubuzu"
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
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
