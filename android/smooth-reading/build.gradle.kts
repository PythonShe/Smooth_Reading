import com.vanniktech.maven.publish.AndroidSingleVariantLibrary

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.maven.publish)
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
    // `annotatedString()` needs Compose's ui-text (AnnotatedString / SpanStyle)
    // at compile time only. It is deliberately `compileOnly`, not `api`: a
    // View-only consumer must not pull the Compose runtime into its APK, and a
    // Compose consumer already has ui-text on its classpath. The class that
    // references Compose is loaded lazily, and consumer-rules.pro carries the
    // matching `-dontwarn` for R8. Documented in README.md ("Install").
    compileOnly(platform(libs.androidx.compose.bom))
    compileOnly(libs.androidx.compose.ui.text)

    testImplementation(libs.junit4)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.text)
}

// Maven Central via the Sonatype Central Portal.
mavenPublishing {
    publishToMavenCentral()
    if (providers.gradleProperty("signingInMemoryKey").isPresent) signAllPublications()
    coordinates(project.group.toString(), "smooth-reading", project.version.toString())
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = true))
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
