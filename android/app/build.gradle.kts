import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.water_balance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Загружаем свойства ключа, используя относительный путь
    val keyProperties = Properties()
    val keyPropertiesFile = file("../key.properties") // Из android/app идем наверх в android/
    keyProperties.load(keyPropertiesFile.inputStream())

    signingConfigs {
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storePassword = keyProperties.getProperty("storePassword")
            // Строим путь к ключу относительно файла key.properties
            storeFile = keyPropertiesFile.parentFile.resolve(keyProperties.getProperty("storeFile"))
        }
    }

    defaultConfig {
        applicationId = "com.example.water_balance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // MyTarget SDK для рекламы (обновленная версия)
    implementation("com.my.target:mytarget-sdk:5.27.2")
}