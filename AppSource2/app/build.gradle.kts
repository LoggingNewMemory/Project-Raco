plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.kanagawa.yamada.project.raco"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.kanagawa.yamada.project.raco"
        minSdk = 24
        targetSdk = 36
        versionCode = 70
        versionName = "7.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // ── RacoSec: Full obfuscation enabled in release ──────────────
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // LACCESS flag injected by build.sh (1 = early access with anti-crack)
            val laccessEnabled = (project.findProperty("LACCESS") ?: "1").toString() == "1"
            buildConfigField("boolean", "LACCESS", if (laccessEnabled) "true" else "false")
        }
        debug {
            isMinifyEnabled = false
            buildConfigField("boolean", "LACCESS", "false") // no anti-crack in debug
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose     = true
        buildConfig = true   // needed for LACCESS flag
    }
}

dependencies {
    implementation("io.coil-kt:coil-compose:2.6.0")
    implementation("com.vanniktech:android-image-cropper:4.6.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.palette:palette-ktx:1.0.0")
}
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}
