plugins {
    alias(libs.plugins.android.library)
    `maven-publish`
}

android {
    namespace = "io.smoothreading.android"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        minSdk = libs.versions.minSdk.get().toInt()
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    explicitApi()
}

// Robolectric's bytecode instrumentation cannot read class files newer than
// JDK 21, and the Gradle daemon may well be running on a newer JDK, so pin the
// unit tests to the same toolchain the code is compiled with.
tasks.withType<Test>().configureEach {
    // The fixture test reads ../../fixtures relative to the project directory.
    systemProperty(
        "smoothreading.fixtures",
        rootProject.projectDir.parentFile.resolve("fixtures").absolutePath,
    )
    javaLauncher.set(
        javaToolchains.launcherFor {
            languageVersion.set(JavaLanguageVersion.of(libs.versions.jdk.get().toInt()))
        }
    )
}

dependencies {
    api(project(":smooth-reading-core"))
    // Compose text only (AnnotatedString / SpanStyle); no Compose runtime and no
    // Compose compiler plugin, because this module declares no @Composable.
    implementation(platform(libs.androidx.compose.bom))
    api(libs.androidx.compose.ui.text)

    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
}

publishing {
    publications {
        register<MavenPublication>("release") {
            afterEvaluate { from(components["release"]) }
            artifactId = "smooth-reading"
            pom {
                name.set("Smooth Reading")
                description.set(
                    "Guided fixation reading for Android: Compose AnnotatedString, Spanned for TextView, and HTML."
                )
                url.set("https://github.com/PythonShe/Smooth_Reading")
                licenses {
                    license {
                        name.set("The Apache License, Version 2.0")
                        url.set("https://www.apache.org/licenses/LICENSE-2.0.txt")
                    }
                }
                developers {
                    developer {
                        id.set("smooth-reading")
                        name.set("Smooth Reading contributors")
                    }
                }
                scm {
                    url.set("https://github.com/PythonShe/Smooth_Reading")
                    connection.set("scm:git:https://github.com/PythonShe/Smooth_Reading.git")
                    developerConnection.set("scm:git:ssh://git@github.com/PythonShe/Smooth_Reading.git")
                }
            }
        }
    }
}
