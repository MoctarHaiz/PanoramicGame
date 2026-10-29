import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// Firebase (analytics + push notifications) is enabled when app/google-services.json
// is present. Download it from the Firebase console; it is not stored in git.
if (file("google-services.json").exists()) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
}

// Release signing: optional keystore.properties next to settings.gradle.kts
// (see keystore.properties.example). Android Studio's "Generate Signed App Bundle"
// works without it.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.HaizStudio.ChakaZulu"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.HaizStudio.ChakaZulu"
        minSdk = 27
        targetSdk = 36
        versionCode = 3
        versionName = "1.1"
    }

    signingConfigs {
        if (!keystoreProperties.isEmpty) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(libs.androidx.activity)
    implementation(libs.play.services.ads)
    implementation(libs.ump)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.messaging)
}
