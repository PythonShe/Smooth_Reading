# Smooth Reading — Android & JVM

Guided fixation reading for Android and plain JVM: the leading letters of every
word are emphasised so the eye has an artificial fixation point. The algorithm
is specified in [`docs/SPEC.md`](../docs/SPEC.md) and produces the same output
as the TypeScript, Swift and Python ports (`fixtures/common` is shared).

Two artifacts are published from this build:

| Artifact | Module | Contents |
| --- | --- | --- |
| `io.smoothreading:smooth-reading` | `smooth-reading/` | Android library (minSdk 26): `spanned()` / `setSmoothText()` for `TextView`, `annotatedString()` for Compose, ICU tokenizer. Depends on core. |
| `io.smoothreading:smooth-reading-core` | `smooth-reading-core/` | Pure Kotlin/JVM, zero dependencies: `tokenize`, `toHtml`, `fixationLength` |

## Install

```kotlin
// build.gradle.kts — Android app or library
dependencies {
    implementation("io.smoothreading:smooth-reading:0.1.0")
}

// build.gradle.kts — plain JVM project (server-side rendering, CLI, desktop)
dependencies {
    implementation("io.smoothreading:smooth-reading-core:0.1.0")
}
```

The Android artifact pulls in the core artifact transitively. Its only other
dependency, `androidx.compose.ui:ui-text` (for `AnnotatedString` /
`SpanStyle`), is declared **`compileOnly`** on purpose:

* A View-only app gets no Compose runtime in its APK. The class that references
  Compose (`SmoothReadingCompose`) is never loaded unless you call
  `annotatedString()`, and the library's consumer ProGuard rules carry the
  matching `-dontwarn androidx.compose.ui.**` so R8 does not complain about
  the classes you do not ship.
* A Compose app already has `ui-text` on its classpath through
  `androidx.compose.ui:ui`, so nothing extra is needed. The library declares
  no `@Composable` function and does not require the Compose compiler plugin.

## TextView

```kotlin
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.android.setSmoothText
import io.smoothreading.android.spanned

textView.setSmoothText("Smooth reading works.")

// Options, plus a dimmed colour on the rest of each word:
textView.setSmoothText(
    "Smooth reading works.",
    SmoothOptions(fixation = 4, saccade = 1),
    restSpan = { ForegroundColorSpan(0x99000000.toInt()) },
)

// Or build the Spannable yourself:
textView.text = SmoothReading.spanned("Smooth reading works.")
```

`spanned()` returns a `SpannableString` over the original text. The fixation
of each word carries a `StyleSpan(Typeface.BOLD)` by default (pass
`fixationSpan = { … }` for something else), and `restSpan` optionally styles the
remainder — e.g. a `ForegroundColorSpan` for an alpha effect. Spans are given as
factories because every span instance covers exactly one range. Words without a
fixation get no span at all, so the result composes with the view's existing
typeface and text appearance.

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
            restStyle = SpanStyle(color = LocalContentColor.current.copy(alpha = 0.75f)),
        )
    )
}
```

`annotatedString()` is a plain function (not `@Composable`), so it can be
called from a `ViewModel` or `remember { }` block and cached.

## HTML and tokens (any JVM target)

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

Existing markup is passed through verbatim by default (`ignoreHtmlTags = true`):
tags, comments and character references such as `&amp;` are left as they are
and act as word boundaries; a bare `&` or a `<` that does not start a tag is
escaped. With `ignoreHtmlTags = false` the input is plain text and every `<`,
`>`, `&`, `"` is escaped.

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

A custom `fixationLength` replaces the algorithm entirely; delegate to
`SmoothReading.fixationLength(word, graphemes, options.copy(fixationLength = null))`
for the cases you do not care about:

```kotlin
val firstHalf = SmoothOptions(fixationLength = { _, graphemes, _ -> graphemes / 2 })
SmoothReading.toHtml("reading", firstHalf) // <b>rea</b>ding
```

## Options

`SmoothOptions` (SPEC §4); every constructor argument is validated with `require`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `Int` (1–5) | `3` | How much of each word is emphasised: ratios 0.20 / 0.35 / 0.50 / 0.65 / 0.80, rounded half up in integer arithmetic and clamped to `1..n`. |
| `saccade` | `Int` (≥ 1) | `1` | `1` = every word, `2` = every second word, … Every word consumes an index, numbers included, even when it gets no fixation. |
| `minWordLength` | `Int` (≥ 0) | `1` | Words shorter than this (in grapheme clusters) get no fixation. |
| `emphasizeNumbers` | `Boolean` | `false` | Whether words made only of decimal digits are emphasised. |
| `locale` | `java.util.Locale?` | `null` | Passed to the break iterators (runtime default when `null`). |
| `fixationLength` | `((word: String, graphemes: Int, options: SmoothOptions) -> Int)?` | `null` | Replaces the default algorithm entirely; the result is clamped to `0..graphemes`. |

`HtmlOptions` wraps a `SmoothOptions` (Kotlin data classes cannot inherit) and
adds:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `smooth` | `SmoothOptions` | `SmoothOptions()` | The fixation options above. |
| `tag` | `String` | `"b"` | Element wrapped around the fixation prefix. |
| `className` | `String?` | `null` | Class attribute for `tag`. |
| `restTag` | `String?` | `null` | Optional element around the rest of the word. Words without a fixation are never wrapped. |
| `restClassName` | `String?` | `null` | Class attribute for `restTag`. |
| `ignoreHtmlTags` | `Boolean` | `true` | Pass existing markup and character references through verbatim instead of escaping them. |
| `skipTags` | `List<String>` | `code, pre, script, style, kbd, samp, textarea` | Elements whose text is never rewritten (case-insensitive). `tag` and `restTag` are always skipped as well, so already-emphasised markup is never wrapped twice. |

Presentation stays in CSS / span styles: the core only emits neutral markup.

## Tokenizers

| Segmenter | Where | Behaviour |
| --- | --- | --- |
| `SpecWordSegmenter` | everywhere; default for `tokenize()` / `toHtml()` | The spec's Unicode scanner: `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`, plus one word per run of Han / Kana / Hangul / Thai. Agrees with every `fixtures/common` case in every port. |
| `IcuWordSegmenter` | Android; default for `spanned()` / `annotatedString()` | `android.icu.text.BreakIterator`: UAX #29 with dictionary breaking for Chinese, Japanese and Thai. Also passes `fixtures/segmenter`. |

The JVM default is deliberately **not** `java.text.BreakIterator`: outside
Android it is the JDK's legacy rule-based word iterator, which keeps
`well-known` as a single word and splits `don’t` into three, both contradicting
SPEC §3. Grapheme counting *does* use `BreakIterator.getCharacterInstance()`,
which is UAX #29 conformant on both runtimes. Any `WordSegmenter` you write
yourself must return segments that concatenate back to the input.

Pass a segmenter explicitly when you need the other behaviour:

```kotlin
SmoothReading.toHtml("我喜欢阅读", segmenter = IcuWordSegmenter(Locale.CHINESE))
// <b>我</b><b>喜</b>欢<b>阅</b>读   (dictionary word breaks)
SmoothReading.toHtml("我喜欢阅读", segmenter = SpecWordSegmenter)
// <b>我喜欢</b>阅读                (one word per CJK run, like the other ports)
SmoothReading.spanned("我喜欢阅读", SmoothOptions(), segmenter = SpecWordSegmenter)
```

## Requirements

* Android `minSdk` 26, `compileSdk` 37
* Java 11 bytecode; both modules are compiled with a JDK 21 toolchain
  (`org.gradle.java.installations.paths` in `gradle.properties` points Gradle
  at the Homebrew JDKs; the Robolectric tests are launched on JDK 21 as well)
* Gradle 9.7.1, Android Gradle Plugin 9.4.0, Kotlin 2.4.20

## Building

```bash
cd android
./gradlew :smooth-reading-core:test :smooth-reading:test :smooth-reading:assembleRelease
./gradlew publishToMavenLocal  # io.smoothreading:{smooth-reading,smooth-reading-core}:0.1.0
```

The README snippets above are mirrored in `ReadmeSnippetsTest` in both modules.
`local.properties` (the Android SDK location) is generated per machine and is
not committed.
