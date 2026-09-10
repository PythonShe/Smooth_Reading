import org.gradle.api.attributes.java.TargetJvmVersion
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    alias(libs.plugins.kotlin.jvm)
    `maven-publish`
}

kotlin {
    explicitApi()
    jvmToolchain(libs.versions.jdk.get().toInt())
    // Java 11 bytecode: the same level the Android artifact is built at, so an
    // app can depend on either module without a jvmTarget mismatch.
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    withSourcesJar()
    withJavadocJar()
}

// Zero runtime dependencies (CLAUDE.md "Stack Policy"). Everything below is
// test-only.
dependencies {
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
    testImplementation(libs.json)
    testRuntimeOnly(libs.junit.platform.launcher)
}

// The published artifact targets Java 11, but JUnit 6 requires 17+. Compile and
// run the tests at the toolchain's own level instead; only `main` is published.
val testJvmTarget = libs.versions.jdk.get()
tasks.named<KotlinCompile>("compileTestKotlin") {
    compilerOptions.jvmTarget.set(JvmTarget.fromTarget(testJvmTarget))
}
tasks.named<JavaCompile>("compileTestJava") {
    options.release.set(testJvmTarget.toInt())
    sourceCompatibility = testJvmTarget
    targetCompatibility = testJvmTarget
}
listOf(configurations.testCompileClasspath, configurations.testRuntimeClasspath).forEach { configuration ->
    configuration.configure {
        attributes.attribute(
            TargetJvmVersion.TARGET_JVM_VERSION_ATTRIBUTE,
            libs.versions.jdk.get().toInt(),
        )
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
    // The FixtureTest reads ../../fixtures relative to the project directory.
    systemProperty("smoothreading.fixtures", rootProject.projectDir.parentFile.resolve("fixtures").absolutePath)
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            artifactId = "smooth-reading-core"
            pom {
                name.set("Smooth Reading Core")
                description.set(
                    "Guided fixation reading for the JVM: tokenizer, fixation algorithm and HTML renderer."
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
