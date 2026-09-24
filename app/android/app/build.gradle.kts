import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de publication : le keystore et son mot de passe vivent hors du
// dépôt, dans ../.agora-secrets/ (voir ../../android-signing-guide.md).
// `rootProject` est android/, donc ce chemin désigne android/key.properties.
val fichierSignature = rootProject.file("key.properties")
val signatureDisponible = fichierSignature.exists()
val proprietes = Properties().apply {
    if (signatureDisponible) fichierSignature.inputStream().use { load(it) }
}

android {
    namespace = "app.agora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.agora"
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
        if (signatureDisponible) {
            create("upload") {
                storeFile = file(proprietes.getProperty("storeFile"))
                storePassword = proprietes.getProperty("storePassword")
                keyAlias = proprietes.getProperty("keyAlias")
                keyPassword = proprietes.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // **Repli sur la clé de débogage, mais jamais en silence.** Sans
            // `key.properties`, `flutter run --release` doit continuer à
            // s'installer sur un appareil : Flutter exige une signature,
            // quelle qu'elle soit. Un binaire ainsi signé est en revanche
            // refusé par Play — après l'envoi, et sans indice sur la cause.
            // L'avertissement est le seul endroit où cela se voit à temps.
            signingConfig = if (signatureDisponible) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn(
                    "ATTENTION : android/key.properties absent. La version de " +
                        "publication est signée avec la clé de DÉBOGAGE : " +
                        "installable localement, refusée par le Play Store."
                )
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
