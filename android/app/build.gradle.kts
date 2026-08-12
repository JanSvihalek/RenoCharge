plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.svihalek.renocharge"
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
        applicationId = "dev.svihalek.renocharge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Zatím se podepisuje ladicím klíčem. APK se rozdává ručně
            // testerům, ne přes obchod; přihlašuje se e-mailem a heslem,
            // takže na otisku certifikátu ve Firebase nic nezávisí.
            // Cenou je, že se podpis mezi buildy liší a novou verzi jde
            // nainstalovat až po odinstalování té staré.
            signingConfig = signingConfigs.getByName("debug")

            // Přidává, nenahrazuje – pravidla od Flutteru i od knihoven
            // zůstávají v platnosti. Co je v souboru a proč, viz
            // proguard-rules.pro.
            proguardFiles("proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
