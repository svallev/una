plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "invalid.pending.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // [Pendiente PD-2] Marcador deliberado (.invalid es un dominio reservado): el definitivo
        // se fija al comprar el dominio neutro. PROHIBIDO subir a una tienda con este valor.
        applicationId = "invalid.pending.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // D12: Android 8.0
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // La app de pruebas convive con la release en el mismo móvil y las
            // pruebas de integración (que borran su BD) nunca tocan tus tareas.
            applicationIdSuffix = ".debug"
        }
        // La crea el plugin de Flutter copiando la de debug antes de este bloque:
        // sin su propio sufijo se instalaría encima de la app real.
        getByName("profile") {
            applicationIdSuffix = ".profile"
        }
        release {
            // F5: firma de subida desde key.properties (fuera del repo, threat-model §6).
            // Hasta entonces, claves de debug para poder probar builds release en local.
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
