# Smooth Reading

[![npm](https://img.shields.io/npm/v/@smooth-reading/core?label=npm&logo=npm)](https://www.npmjs.com/package/@smooth-reading/core)
[![npm downloads](https://img.shields.io/npm/dm/@smooth-reading/core?label=npm%20downloads&logo=npm)](https://www.npmjs.com/package/@smooth-reading/core)
[![PyPI](https://img.shields.io/pypi/v/smooth-reading?label=PyPI&logo=pypi&logoColor=white)](https://pypi.org/project/smooth-reading/)
[![PyPI downloads](https://img.shields.io/pypi/dm/smooth-reading?label=PyPI%20downloads&logo=pypi&logoColor=white)](https://pypi.org/project/smooth-reading/)
[![pub.dev](https://img.shields.io/pub/v/smooth_reading?label=pub.dev&logo=dart&logoColor=white)](https://pub.dev/packages/smooth_reading)
[![crates.io](https://img.shields.io/crates/v/smooth-reading?label=crates.io&logo=rust&logoColor=white)](https://crates.io/crates/smooth-reading)
[![Maven Central](https://img.shields.io/maven-central/v/io.github.pythonshe/smooth-reading?label=Maven%20Central&logo=apachemaven)](https://central.sonatype.com/artifact/io.github.pythonshe/smooth-reading)
[![SwiftPM](https://img.shields.io/github/v/release/PythonShe/Smooth_Reading?include_prereleases&label=SwiftPM&logo=swift&logoColor=white)](https://github.com/PythonShe/Smooth_Reading/releases)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPythonShe%2FSmooth_Reading%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/PythonShe/Smooth_Reading)
[![Apple platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FPythonShe%2FSmooth_Reading%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/PythonShe/Smooth_Reading)
[![GitHub stars](https://img.shields.io/github/stars/PythonShe/Smooth_Reading?style=flat&logo=github)](https://github.com/PythonShe/Smooth_Reading/stargazers)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Open-source, framework-friendly **guided fixation reading**: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

```
Smooth reading works.   →   **Smo**oth **read**ing **wor**ks.
```

The technique is similar to commercial fixation-reading products, but this project is independent, clean-room, trademark-free, and licensed under Apache-2.0. The algorithm is documented in full in [docs/SPEC.md](docs/SPEC.md), ensuring that every port produces identical output.

## Packages

| Package | Registry | Platforms | Description |
| --- | --- | --- | --- |
| [`@smooth-reading/core`](packages/core) | npm | Web, Node.js, React Native, Deno, Bun | Zero-dependency tokenizer, HTML transformer, DOM applier, streaming transform. |
| [`SmoothReading`](swift) | Swift Package Manager | iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+ | Native Swift 6 library. `NSAttributedString` for UIKit/AppKit, `AttributedString` for SwiftUI. |
| [`io.github.pythonshe:smooth-reading`](android) | Maven Central | Android (minSdk 24), JVM | `AnnotatedString` for Jetpack Compose, `Spanned` for Android Views, pure JVM core. |
| [`smooth-reading`](python) | PyPI | Python 3.10+ | Zero-dependency Python library, type-annotated, with a built-in CLI. |
| [`smooth_reading`](dart) | pub.dev | Dart 3.0+, Flutter (iOS, Android, web, desktop), server | Pure Dart. Sealed `Token` for `TextSpan` rendering, `toHtml`, `toMarkdown`, pluggable `Segmenter` for platform ICU. |
| [`smooth-reading`](rust) | crates.io | Rust 1.85+ (std only, no `unsafe`) | Borrowed `Token<'a>` for any text stack, `to_html`, `to_markdown`, `Segmenter` trait for ICU, `smooth-reading` CLI. |

---

## Quick start

### Web & TypeScript

```bash
pnpm add @smooth-reading/core
# npm install @smooth-reading/core  ·  yarn add @smooth-reading/core
```

```ts
import { toHtml } from "@smooth-reading/core";

toHtml("Smooth reading works.");
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'

toHtml("Smooth reading works.", { fixation: 5, saccade: 2, tag: "span", className: "sr-fixation" });
// '<span class="sr-fixation">Smoot</span>h reading <span class="sr-fixation">work</span>s.'
```

### React / Next.js

Render directly from tokens without `innerHTML` (see [docs/recipes/react.md](docs/recipes/react.md)):

```tsx
import { tokenize } from "@smooth-reading/core";

export function SmoothText({ children, ...options }) {
  return tokenize(children, options).map((token, index) =>
    token.type === "word" && token.fixation > 0 ? (
      <span key={index}>
        <b>{token.fixationText}</b>
        {token.restText}
      </span>
    ) : (
      token.text
    )
  );
}
```

### Apple (Swift)

```swift
// Package.swift
.package(url: "https://github.com/PythonShe/Smooth_Reading.git", from: "0.3.0")
```

```swift
import SmoothReading

// UIKit / AppKit convenience
label.applySmoothReading("Smooth reading works.")

// SwiftUI
Text(SmoothReading.attributedString("Smooth reading works.", options: SmoothOptions(fixation: 3)))
```

### Android (Kotlin)

```kotlin
// build.gradle.kts — resolves from Maven Central
implementation("io.github.pythonshe:smooth-reading:0.3.0")
```

```kotlin
import io.smoothreading.SmoothReading
import io.smoothreading.android.annotatedString
import io.smoothreading.android.setSmoothText

// Jetpack Compose
Text(SmoothReading.annotatedString("Smooth reading works."))

// Android Views (TextView)
textView.setSmoothText("Smooth reading works.")
```

### Python

```bash
pip install smooth-reading
```

```python
from smooth_reading import to_html

to_html("Smooth reading works.")
# '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
```

### Flutter & Dart

```bash
flutter pub add smooth_reading   # or: dart pub add smooth_reading
```

```dart
import 'package:smooth_reading/smooth_reading.dart';

// Flutter: build TextSpans from tokens (full widget in docs/recipes/flutter.md)
TextSpan(children: [
  for (final token in tokenize('Smooth reading works.'))
    switch (token) {
      WordToken(fixation: > 0, :final fixationText, :final restText) =>
        TextSpan(children: [
          TextSpan(text: fixationText, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: restText),
        ]),
      WordToken(:final text) || SeparatorToken(:final text) => TextSpan(text: text),
    },
]);

// Server / web: HTML
toHtml('Smooth reading works.');
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
```

### Rust

```bash
cargo add smooth-reading
```

```rust
use smooth_reading::{to_html, tokenize, HtmlOptions, Options, Token};

let options = Options::default();
assert_eq!(
    to_html("Smooth reading works.", &options, &HtmlOptions::default()),
    "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.",
);

// Tokens borrow from the input; render them with any text stack.
for token in tokenize("Smooth reading works.", &options) {
    match token {
        Token::Word { fixation_text, rest_text, .. } => print!("[{fixation_text}]{rest_text}"),
        Token::Separator { text } => print!("{text}"),
    }
}
```

The crate also installs a `smooth-reading` command (`cargo install smooth-reading`) that reads a file or standard input and writes HTML or Markdown.

---

## Why another library?

Existing open-source implementations are typically single-purpose string replacers, archived browser extensions, or GPL/AGPL licensed. Most split contractions, break bidirectional text, inject unescaped `innerHTML`, and fail completely on scripts without spaces.

Smooth Reading was built to provide an enterprise-grade, specification-backed foundation:

- **Strict cross-platform parity**: Governed by a formal specification ([docs/SPEC.md](docs/SPEC.md)). Every port passes the same shared test fixtures (`fixtures/common/`), guaranteeing identical output across Web, iOS, macOS, Android, Python, Dart/Flutter and Rust.
- **Multilingual & Unicode fidelity**: Correct dictionary word boundaries for non-space scripts (Chinese, Japanese, Thai, Lao, Khmer, Burmese), ligature-safe Indic conjuncts (Unicode 15.1 GB9c), non-destructive bidirectional (RTL) handling for Arabic and Hebrew, and grapheme cluster counting instead of naive code units.
- **Modern UI integration**: Framework-native primitives without unsafe HTML injection. Renders directly as React/Vue/Svelte components, Flutter `TextSpan`s, Jetpack Compose `AnnotatedString`, UIKit/AppKit `NSAttributedString`, and SwiftUI `AttributedString`.
- **Zero runtime dependencies**: Pure Apache-2.0 license, zero external dependencies across all ports, zero telemetry, and zero network calls. Runs completely offline.

---

## Framework recipes

Framework adapters are intentionally not published as separate packages; they are lightweight, copy-paste components built directly on `@smooth-reading/core`'s `tokenize()`. They render native elements (avoiding `innerHTML`), making them safe for untrusted input and server-side rendering:

| Framework / Platform | Recipe Guide | Description |
| --- | --- | --- |
| **React / Next.js / Remix** | [docs/recipes/react.md](docs/recipes/react.md) | Pure components (RSC safe), TanStack Query hooks, and ref callbacks. |
| **React Native / Expo** | [docs/recipes/react-native.md](docs/recipes/react-native.md) | Nested `<Text>` rendering compatible with Hermes and Expo. |
| **Vue 3** | [docs/recipes/vue.md](docs/recipes/vue.md) | Computed `tokenize()` component and `v-smooth` directive. |
| **Svelte 5** | [docs/recipes/svelte.md](docs/recipes/svelte.md) | Runes-based component and `use:smooth` action. |
| **Angular (17+)** | [docs/recipes/angular.md](docs/recipes/angular.md) | Signals-based standalone component and directive. |
| **Web Components / HTML** | [docs/recipes/web-component.md](docs/recipes/web-component.md) | Zero-build custom element and progressive DOM enhancement. |
| **Markdown Pipelines** | [docs/recipes/markdown.md](docs/recipes/markdown.md) | Rehype plugins (Astro, Docusaurus, Next MDX) and pure Markdown transforms. |

Explore all recipes in [docs/recipes/](docs/recipes/).

---

## What the evidence says

Controlled empirical studies (Readwise 2022, Snell 2024, Možina et al. 2025) found **no reading-speed benefit** from this technique for the general population, and no controlled study has demonstrated a benefit for ADHD or dyslexic readers. Many people nevertheless report that they subjectively prefer reading this way. 

Treat it as an optional reading *preference* you can offer your users, not an objective speed-reading or cognitive enhancement feature. Scientific literature:

- Readwise reader study, 2022, ~1,900 participants: [blog.readwise.io](https://blog.readwise.io/).
- Snell, *Acta Psychologica* (2024): [sciencedirect.com](https://www.sciencedirect.com/science/article/pii/S0001691824001811).
- Možina, Kovačević & Blaznik, *SAGE Open* (2025): [doi:10.1177/21582440251376158](https://journals.sagepub.com/doi/10.1177/21582440251376158).
- *Attention, Perception & Psychophysics* (2025): [doi:10.3758/s13414-025-03067-w](https://link.springer.com/article/10.3758/s13414-025-03067-w).

---

## Design principles

- **One documented algorithm**: Shared JSON fixtures, identical math, and identical output across languages.
- **Unicode first**: `Intl.Segmenter` and ICU word breaking for non-space scripts, grapheme-cluster counting, and respectful handling of diacritics and ligatures.
- **Safe by default**: Automatically skips `<code>`, `<pre>`, `<script>`, `<style>`, `<kbd>`, `<samp>`, and `<textarea>`; escapes all emitted text; avoids `innerHTML` in UI recipes.
- **Presentation is CSS**: The core emits neutral markup (`<b>` or configurable tags/classes); weight, color, and opacity remain fully customizable via stylesheet custom properties.
- **Zero runtime dependencies**: Self-contained, lightweight, and offline.

---

## Languages and scripts

International scripts and right-to-left text are primary architectural requirements of this project, not an afterthought. Every port passes `fixtures/common/scripts.json` (Korean, Vietnamese, Hindi, Bengali, Tamil, Arabic, Hebrew, Persian, Urdu, Greek, Turkish, German, mixed-direction text, emoji); ICU-backed ports also pass `fixtures/segmenter/` (Chinese, Japanese, Thai, Lao, Khmer, Burmese, bidi paragraphs). See [docs/LANGUAGES.md](docs/LANGUAGES.md) for the detailed specification and engine comparisons.

| Script | `@smooth-reading/core` | Swift | Android | Python | Dart | Rust | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Latin, Greek, Cyrillic, Vietnamese, Turkish, German | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | spec regex | spec regex | Identical everywhere |
| Korean (Hangul, spaces) | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | spec regex | spec regex | Identical; decomposed jamo compose in all ports |
| Chinese, Japanese | `Intl.Segmenter` dictionary | ICU dictionary | `android.icu` dictionary | One word per run | One word per run | One word per run | Dictionary breaks in ICU ports; predictable run rule in Python, Dart and Rust |
| Thai, Lao, Khmer, Burmese | `Intl.Segmenter` dictionary | ICU dictionary | `android.icu` dictionary | One word per run | One word per run | Dictionary breaks in ICU ports; predictable run rule in Python |
| Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | spec regex | spec regex | Identical; conjuncts (`क्ष`) are one cluster (Unicode 15.1 GB9c) |
| Tamil and other Indic scripts | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | spec regex | spec regex | Identical; marks stay attached to base consonants |
| Arabic, Persian, Urdu, Hebrew | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | spec regex | spec regex | Identical; tashkeel and niqqud stay with base letters; Persian ZWNJ preserved in ICU ports |
| Digits of any script (`\p{Nd}`) | — | — | — | — | — | — | Unemphasised unless `emphasizeNumbers: true`; still count towards `saccade` |
| Emoji, modifiers, ZWJ sequences | — | — | — | — | — | — | Treated as separators; passed through untouched |

### Typographic considerations

**Bold is typographically weak for some scripts.** Many Arabic, Devanagari, Bengali, and Thai typefaces lack a dedicated bold face or have a bold weight that barely differs from regular. Synthetic bolding can also blur intricate conjuncts and vowel marks. We recommend emitting semantic classes instead of `<b>` and styling fixations with color, weight, or opacity:

```ts
toHtml(text, { tag: "span", className: "sr-fixation", restTag: "span", restClassName: "sr-rest" });
```

```css
.sr-fixation { color: var(--sr-fixation-color, #1d4ed8); font-weight: 600; }
.sr-rest     { opacity: var(--sr-rest-opacity, 0.85); }
```

In Swift and Android, pass custom attributes directly: `fixationAttributes` in `nsAttributedString` / `attributedString`, or `SpanStyle(color = …)` in `annotatedString()`. In Rust, render `tokenize()` output with whatever styling your text stack offers.

### Bidirectional text (RTL)

The fixation point is always the *logical* start of the word (the first characters read). Arabic and Hebrew words are naturally emphasised on their right-hand side without requiring special directional wrappers. 

Emitted markup and attributed strings never insert `dir` attributes, `<bdi>` elements, or artificial bidi control characters. Mixed-direction inputs (`Hello مرحبا world`, RTL sentences with embedded Latin terms and numbers) are tested in every port to ensure lossless roundtripping.

---

## Releases

All six ports share one version number and one git tag (`vX.Y.Z`); see
[CHANGELOG.md](CHANGELOG.md) for release notes.

| Port | Where it is published | Current channel |
| --- | --- | --- |
| `@smooth-reading/core` | [npm](https://www.npmjs.com/package/@smooth-reading/core) | `pnpm add @smooth-reading/core` (`0.3.0`) |
| `SmoothReading` | [GitHub releases](https://github.com/PythonShe/Smooth_Reading/releases) (SwiftPM resolves git tags directly) and the [Swift Package Index](https://swiftpackageindex.com/PythonShe/Smooth_Reading) | `from: "0.3.0"` |
| `io.github.pythonshe:smooth-reading` | [Maven Central](https://central.sonatype.com/artifact/io.github.pythonshe/smooth-reading) | `0.3.0` |
| `smooth-reading` | [PyPI](https://pypi.org/project/smooth-reading/) | `pip install smooth-reading` (`0.3.0`) |
| `smooth_reading` | [pub.dev](https://pub.dev/packages/smooth_reading) | `dart pub add smooth_reading` (`0.3.0`) |
| `smooth-reading` (Rust) | [crates.io](https://crates.io/crates/smooth-reading) | `cargo add smooth-reading` (`0.3.0`) |

The public API is described in [docs/SPEC.md](docs/SPEC.md); it follows
semantic versioning from `0.3.0` on, with breaking changes only in minor
versions while the major is `0`.

## Contributing

External pull requests are not accepted for now; bug reports, test cases, and questions via issues are warmly welcome, and forks are encouraged. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

```bash
# TypeScript core
pnpm install && pnpm build && pnpm test

# Swift package
cd swift && swift test

# Android & JVM
cd android && ./gradlew test

# Python package
cd python && python -m pip install -e ".[dev]" && pytest && mypy --strict smooth_reading

# Dart package
cd dart && dart pub get && dart analyze && dart test

# Rust crate
cd rust && cargo clippy --all-targets -- -D warnings && cargo test
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on maintaining multi-port parity and [CHANGELOG.md](CHANGELOG.md) for version release notes.

## License

Apache-2.0. See [LICENSE](LICENSE).
