import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// De ondertekening van de release-APK staat in signing/keystore.properties (en de sleutel ernaast); dezelfde
// sleutel als V1, zodat deze versie als update over 1.0.0 heen kan. Die map zit in .gitignore: sleutel en
// wachtwoord gaan nooit mee naar GitHub. Ontbreekt hij, dan bouwt de release gewoon, maar ongetekend.
val sleutel = Properties().apply {
    val f = rootProject.file("signing/keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "nl.edsoft.klaverjas"
    compileSdk = 37

    defaultConfig {
        applicationId = "nl.edsoft.klaverjas"
        minSdk = 26
        targetSdk = 37
        versionCode = 9
        versionName = "2.3.0"

        // De naam onder het pictogram; de manifestPlaceholders per buildtype hieronder overschrijven hem.
        manifestPlaceholders["appLabel"] = "Klaverjas-42"
    }

    signingConfigs {
        if (!sleutel.isEmpty) {
            create("release") {
                storeFile = rootProject.file(sleutel.getProperty("storeFile"))
                storePassword = sleutel.getProperty("storePassword")
                keyAlias = sleutel.getProperty("keyAlias")
                keyPassword = sleutel.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Een debug-build (wat Android Studio op een toestel zet) heeft een eigen id, een eigen naam en
        // een ander pictogram, zodat V2 naast V1 kan draaien met aparte tellingen en instellingen.
        // De release-build, die naar de Play Store gaat, houdt het gewone id nl.edsoft.klaverjas.
        debug {
            applicationIdSuffix = ".v2"
            manifestPlaceholders["appLabel"] = "Klaverjas-42 V2"
        }
        release {
            isMinifyEnabled = false
            if (!sleutel.isEmpty) signingConfig = signingConfigs.getByName("release")
        }
    }

    // Kotlin is built into AGP 9; jvmTarget follows targetCompatibility.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":core"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    debugImplementation(libs.androidx.ui.tooling)

    testImplementation(libs.junit)
}
