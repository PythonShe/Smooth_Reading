# The library is plain Kotlin with no reflection; nothing to keep.
#
# `annotatedString()` (class io.smoothreading.android.SmoothReadingCompose)
# references androidx.compose.ui:ui-text, which is a compileOnly dependency.
# View-only apps that do not ship Compose would otherwise fail R8's missing
# class check for a class they never load.
-dontwarn androidx.compose.ui.**
