plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "kwz.love2d.launcher" // this package is placeholder but i forgot to change it. its kinda cringe
    compileSdk = 34

    defaultConfig {
        applicationId = "kwz.love2d.launcher"
        minSdk = 24
        targetSdk = 34
        versionCode = 57
        versionName = "0.17.40"

        buildConfigField("String", "GITHUB_REPOSITORY_URL", "\"https://github.com/kazwtto/KristalLauncher\"")
        buildConfigField("String", "GITHUB_API_URL", "\"https://api.github.com/repos/kazwtto/KristalLauncher\"")
        buildConfigField("String", "PATCH_CATALOG_URL", "\"https://raw.githubusercontent.com/kazwtto/KristalLauncher/main/patches/catalog.json\"")
        buildConfigField("String", "TRANSLATION_CATALOG_URL", "\"https://raw.githubusercontent.com/kazwtto/KristalLauncher/main/translations/catalog.json\"")
        buildConfigField("String", "KRISTAL_RELEASES_API_URL", "\"https://api.github.com/repos/KristalTeam/Kristal/releases?per_page=100\"")

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        buildConfig = true
        viewBinding = true
    }
    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:.*:<dir>_*:!CVS:!thumbs.db:!picasa.ini:!*~:!gamepad_patch"
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.apache.commons:commons-compress:1.28.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.5.2")
}
