# Smooth Reading — Android & JVM

Guided fixation reading for Android and Kotlin/JVM: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this library is an independent, clean-room, Apache-2.0 implementation built strictly to the monorepo [specification](../docs/SPEC.md), producing identical results to the TypeScript, Swift, and Python ports.

Two distinct artifacts are published:

| Artifact | Target | Description |
| --- | --- | --- |
| `io.smoothreading:smooth-reading` | Android (minSdk 26+) | Full Android library: `spanned()` and `setSmoothText()` for `TextView`, `annotatedString()` for Jetpack Compose, and `IcuWordSegmenter` for dictionary word breaking. |
| `io.smoothreading:smooth-reading-core` | Any JVM target | Pure Kotlin/JVM, zero dependencies: `tokenize()`, `toHtml()`, `fixationLength()`, and `SpecWordSegmenter`. Ideal for server-side rendering, desktop, and backend pipelines. |

Every code snippet below is verified by unit tests in `ReadmeSnippetsTest`.

---

## Installation

```kotlin
// build.gradle.kts — Android app or library
dependencies {
    implementation("io.smoothreading:smooth-reading:0.1.0")
}

// build.gradle.kts — Plain Kotlin/JVM project (SSR, desktop, CLI)
dependencies {
    implementation("io.smoothreading:smooth-reading-core:0.1.0")
}
```

### Lightweight Compose integration

The Android artifact includes `io.smoothreading:smooth-reading-core` transitively. Its only other dependency, `androidx.compose.ui:ui-text` (for `AnnotatedString` and `SpanStyle`), is declared **`compileOnly`**:

- **View-only applications** incur no Compose runtime overhead in their APK. The Compose adapter class (`SmoothReadingCompose`) is only loaded when `annotatedString()` is invoked, and consumer ProGuard rules include `-dontwarn androidx.compose.ui.**`.
- **Jetpack Compose applications** already have `ui-text` provided transitively via `androidx.compose.ui:ui`. The library requires no Compose compiler plugin and adds minimal method count.

---

## Usage

### Android Views (`TextView`)

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

- `spanned()` returns a `SpannableString` over the original input text.
- Fixations apply `StyleSpan(Typeface.BOLD)` by default (override via `fixationSpan = { … }`).
- Spans are provided via factory lambdas because each Android span instance covers exactly one range. Words without a fixation receive no span, compositing naturally with the view's existing typography.

---

### Jetpack Compose

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

`annotatedString()` is a standard Kotlin function (not `@Composable`), making it safe to compute in `ViewModel` classes, background coroutines, or `remember(body)` blocks.

---

### HTML and Tokens (Any JVM target)

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

By default (`ignoreHtmlTags = true`), existing HTML tags, comments, and character entities (`&amp;`) pass through unchanged and act as word boundaries. Set `ignoreHtmlTags = false` to treat input as plain text and escape all HTML characters.

Access structured tokens directly:

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

To replace the fixation algorithm entirely:

```kotlin
val firstHalf = SmoothOptions(fixationLength = { _, graphemes, _ -> graphemes / 2 })
SmoothReading.toHtml("reading", firstHalf) // <b>rea</b>ding
```

---

## Configuration options

### Algorithm options (`SmoothOptions`)

All parameters are strictly validated at construction:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `Int` (1..5) | `3` | Fixation strength: ratios `0.20 / 0.35 / 0.50 / 0.65 / 0.80`, rounded half up and clamped to `1..n`. |
| `saccade` | `Int` (≥ 1) | `1` | Emphasises every *n*-th word (`1` = every word, `2` = every second word). Word tokens consume an index, including numbers and short words. |
| `minWordLength` | `Int` (≥ 0) | `1` | Words with fewer grapheme clusters receive no fixation. |
| `emphasizeNumbers` | `Boolean` | `false` | Whether words composed entirely of decimal digits are emphasised. |
| `locale` | `java.util.Locale?` | `null` | Locale passed to break iterators (falls back to runtime default if `null`). |
| `fixationLength` | `((String, Int, SmoothOptions) -> Int)?` | `null` | Custom lambda overriding the fixation algorithm. Output is clamped to `0..graphemes`. |

### HTML options (`HtmlOptions`)

`HtmlOptions` wraps `SmoothOptions` in its `smooth` property:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `smooth` | `SmoothOptions` | `SmoothOptions()` | The base algorithm configuration. |
| `tag` | `String` | `"b"` | Tag name wrapping the fixation prefix. |
| `className` | `String?` | `null` | Optional `class` attribute for the fixation element. |
| `restTag` | `String?` | `null` | Optional tag name wrapping the remainder of the word. Words without fixation are never wrapped. |
| `restClassName` | `String?` | `null` | Optional `class` attribute for the rest element. |
| `ignoreHtmlTags` | `Boolean` | `true` | Preserves existing tags and character references (`&amp;`, `&#x27;`). When `false`, treats input as plain text. |
| `skipTags` | `List<String>` | `code, pre, script, style, kbd, samp, textarea` | Case-insensitive list of element tag names whose inner text is never altered. |

---

## Word segmentation & Tokenizers

| Segmenter | Environment | Characteristics |
| --- | --- | --- |
| `SpecWordSegmenter` | All JVM runtimes (default for `tokenize()` / `toHtml()`) | Spec-compliant Unicode scanner (`[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`), grouping runs of Han, Kana, Hangul, or Thai into unified words. Guarantees byte-identical output with `fixtures/common/`. |
| `IcuWordSegmenter` | Android (default for `spanned()` / `annotatedString()`) | Built on `android.icu.text.BreakIterator`. Provides full ICU dictionary-based segmentation for Chinese, Japanese, and Thai. Passes `fixtures/segmenter/`. |

The JVM default deliberately avoids `java.text.BreakIterator` for word breaking, as legacy JDK break iterators misclassify hyphens and contractions. 

Grapheme cluster counting leverages `BreakIterator.getCharacterInstance()`, supplemented with a post-pass for Hangul jamo composition and Indic conjunct linking (Unicode 15.1 rule GB9c). This ensures conjuncts like `क्ष` remain unified as single clusters across all supported JDK versions.

You can specify a segmenter explicitly when needed:

```kotlin
SmoothReading.toHtml("我喜欢阅读", segmenter = IcuWordSegmenter(Locale.CHINESE))
// <b>我</b><b>喜</b>欢<b>阅</b>读   (dictionary word breaks)

SmoothReading.toHtml("我喜欢阅读", segmenter = SpecWordSegmenter)
// <b>我喜欢</b>阅读                (one word per CJK run)

SmoothReading.spanned("我喜欢阅读", SmoothOptions(), segmenter = SpecWordSegmenter)
```

---

## Build requirements

- **Android SDK**: `minSdk` 26, `compileSdk` 37
- **Bytecode target**: Java 11 bytecode compiled with a JDK 21 toolchain
- **Build toolchain**: Gradle 9.7.1, Android Gradle Plugin 9.4.0, Kotlin 2.4.20

```bash
cd android
./gradlew :smooth-reading-core:test :smooth-reading:test :smooth-reading:assembleRelease
./gradlew publishToMavenLocal
```

---

## License

Apache-2.0. See [LICENSE](../LICENSE).
