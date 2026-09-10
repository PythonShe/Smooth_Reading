# Smooth Reading — Android & JVM

Guided fixation reading for Android and plain JVM: the leading letters of every
word are emphasised so the eye has an artificial fixation point. The algorithm
is specified in [`docs/SPEC.md`](../docs/SPEC.md) and produces the same output
as the TypeScript, Swift and Python ports (`fixtures/common` is shared).

Two artifacts are published from this build:

| Artifact | Module | Contents |
| --- | --- | --- |
| `io.smoothreading:smooth-reading-core` | `smooth-reading-core/` | Pure Kotlin/JVM, zero dependencies: `tokenize`, `toHtml`, `fixationLength` |
| `io.smoothreading:smooth-reading` | `smooth-reading/` | Android library (minSdk 26): Compose `AnnotatedString`, `Spanned` for `TextView`, ICU tokenizer |

## Install

```kotlin
// build.gradle.kts — Android app or library
dependencies {
    implementation("io.smoothreading:smooth-reading:0.1.0")
}

// A plain JVM project (server-side rendering, CLI, desktop):
dependencies {
    implementation("io.smoothreading:smooth-reading-core:0.1.0")
}
```

The Android artifact depends on the core artifact transitively, and on
`androidx.compose.ui:ui-text` for `AnnotatedString`. It declares no
`@Composable` functions, so no Compose compiler plugin is required in
consumers that only use `spanned()`.

## Jetpack Compose

```kotlin
import androidx.compose.material3.Text
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.android.annotatedString

@Composable
fun Article(body: String) {
    Text(
        SmoothReading.annotatedString(
            body,
            options = SmoothOptions(fixation = 3, saccade = 1),
            fixationStyle = SpanStyle(fontWeight = FontWeight.Bold),
            restStyle = null, // e.g. SpanStyle(color = LocalContentColor.current.copy(alpha = 0.75f))
        )
    )
}
```

## TextView

```kotlin
import io.smoothreading.SmoothReading
import io.smoothreading.android.spanned

textView.text = SmoothReading.spanned("Smooth reading works.")
```

The emphasis is a plain `StyleSpan(Typeface.BOLD)`, so it composes with the
view's existing typeface and text appearance.

## HTML (any JVM target)

```kotlin
import io.smoothreading.HtmlOptions
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading

SmoothReading.toHtml("Smooth reading works.")
// <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.

SmoothReading.toHtml(
    "Smooth reading works.",
    HtmlOptions(SmoothOptions(fixation = 4), tag = "span", className = "sr-fixation"),
)
// <span class="sr-fixation">Smoo</span>th …
```

Tokens are also available directly, which is what the adapters above use:

```kotlin
SmoothReading.tokenize("well-known").forEach { token ->
    when (token) {
        is SmoothToken.Word -> println("${token.fixationText}|${token.restText}")
        is SmoothToken.Separator -> println("sep ${token.text}")
    }
}
// we|ll
// sep -
// kno|wn
```

## Options

`SmoothOptions` (SPEC §4):

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `Int` (1–5) | `3` | How much of each word is emphasised: ratios 0.20 / 0.35 / 0.50 / 0.65 / 0.80, rounded half up and clamped to `1..n`. |
| `saccade` | `Int` (≥ 1) | `1` | `1` = every word, `2` = every second word, … Numbers consume a word index even when they are not emphasised. |
| `minWordLength` | `Int` | `1` | Words shorter than this (in grapheme clusters) get no fixation. |
| `emphasizeNumbers` | `Boolean` | `false` | Whether words made only of digits are emphasised. |
| `locale` | `java.util.Locale?` | `null` | Passed to the break iterators (runtime default when `null`). |
| `fixationLength` | `((word: String, graphemes: Int, options: SmoothOptions) -> Int)?` | `null` | Replaces the default algorithm entirely. |

`HtmlOptions` wraps a `SmoothOptions` (Kotlin data classes cannot inherit) and
adds:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `smooth` | `SmoothOptions` | `SmoothOptions()` | The fixation options above. |
| `tag` | `String` | `"b"` | Element wrapped around the fixation prefix. |
| `className` | `String?` | `null` | Class attribute for `tag`. |
| `restTag` | `String?` | `null` | Optional element around the rest of the word. |
| `restClassName` | `String?` | `null` | Class attribute for `restTag`. |
| `ignoreHtmlTags` | `Boolean` | `true` | Pass existing markup through verbatim instead of escaping it. |
| `skipTags` | `List<String>` | `code, pre, script, style, kbd, samp, textarea` | Elements whose text is never rewritten. The emphasis `tag` is always skipped as well, so already-emphasised markup is never wrapped twice. |

Presentation stays in CSS / span styles: the core only emits neutral markup.

## Tokenizers

| Segmenter | Where | Behaviour |
| --- | --- | --- |
| `SpecWordSegmenter` (default) | everywhere | The spec's Unicode scanner: `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`, plus one word per run of Han / Kana / Hangul / Thai. Agrees with every `fixtures/common` case in every port. |
| `IcuWordSegmenter` | Android, default for `annotatedString()` / `spanned()` | `android.icu.text.BreakIterator`: UAX #29 with dictionary breaking for Chinese, Japanese and Thai. Also passes `fixtures/segmenter`. |
| `BreakIteratorWordSegmenter` | any JVM | `java.text.BreakIterator` — ICU on Android, the JDK's legacy rule-based iterator elsewhere. |

The JVM default is **not** `java.text.BreakIterator`: the JDK's rule-based word
iterator keeps `well-known` as a single word and splits `don’t` into three,
both of which contradict SPEC §3. Grapheme counting *does* use
`BreakIterator.getCharacterInstance()`, which is UAX #29 conformant on both
runtimes.

Pass a segmenter explicitly when you need the other behaviour:

```kotlin
SmoothReading.toHtml(text, HtmlOptions(), IcuWordSegmenter(Locale.JAPANESE))
SmoothReading.spanned(text, SmoothOptions(), SpecWordSegmenter)
```

## Requirements

* Android `minSdk` 26, `compileSdk` 37
* Java 11 bytecode; both modules are compiled with a JDK 21 toolchain
* Gradle 9.7.1, Android Gradle Plugin 9.4.0, Kotlin 2.4.20

## Building

```bash
cd android
./gradlew :smooth-reading-core:test :smooth-reading:assembleRelease
./gradlew test                 # core + Robolectric unit tests
./gradlew publishToMavenLocal  # io.smoothreading:{smooth-reading,smooth-reading-core}:0.1.0
```

`local.properties` (the Android SDK location) is generated per machine and is
not committed.
