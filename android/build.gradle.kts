plugins {
    // AGP 9 brings its own Kotlin support, so the Android module needs no
    // separate Kotlin plugin; the pure-JVM module uses kotlin("jvm").
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.maven.publish) apply false
}

allprojects {
    group = "io.smoothreading"
    version = "0.1.0-rc.1"
}
