# Changelog

All notable changes to this project are documented here. Versions are bumped
together across all six ports and releases are tagged `vX.Y.Z`.

## 0.3.0 — 2026-09-11

Adds a sixth first-party port for Rust. No algorithm changes: every port
still produces byte-identical output on the shared fixture suite.

### New port: `smooth-reading` (Rust, crates.io)

- Std only, zero runtime dependencies, `#![forbid(unsafe_code)]`, edition
  2024, MSRV 1.85 (the edition floor). Rust's standard library has no Unicode general-category
  lookup, so the crate ships a generated code-point range table
  (`rust/src/unicode_data.rs`, from the Unicode Character Database) and a
  hand-written scanner that mirrors the Python port: the spec regex, the
  no-space-script run rule and the UAX #29 grapheme approximation (Hangul
  jamo composition, Indic conjunct linking, combining marks, ZWJ, CR+LF).
- `tokenize` returns borrowed `Token<'a>` values (`Word` / `Separator`)
  that slice the input without copying; `to_html`, `to_markdown`,
  `fixation_length`, `escape_html`, a clamping `Options` builder and
  `HtmlOptions`.
- A `Segmenter` trait with the default `SpecSegmenter`, so an application can
  plug in an ICU word breaker (for example `icu_segmenter`) for dictionary
  based Chinese, Japanese and Thai breaks without touching the algorithm.
- A `smooth-reading` command (`cargo install smooth-reading`) with the same
  flags as the Python CLI.

### Release engineering

- `ci.yml` builds and tests the crate on the 1.85 floor and on stable (fmt,
  clippy, doc, publish dry-run); `release.yml` verifies the crate version and
  publishes to crates.io with the `CARGO_REGISTRY_TOKEN` secret, skipping
  versions that already exist.

## 0.2.0 — 2026-09-10

First stable release. Adds a fifth first-party port for Dart and Flutter and
closes every cross-port divergence found in a full parity audit of the four
existing ports, so all five now produce byte-identical output on an extended
shared fixture suite.

### New port: `smooth_reading` (Dart, pub.dev)

- Pure Dart, zero dependencies, Dart 3.0+ (Flutter 3.10+); runs in Flutter on
  every platform, on the server and on the web.
- `tokenize` returns a sealed `Token` (`WordToken` / `SeparatorToken`) that
  maps directly onto Flutter `TextSpan`s; `toHtml`, `toMarkdown`,
  `fixationLength`, a `const` `SmoothOptions`, and `escapeHtml`.
- A `Segmenter` interface: the default `SpecSegmenter` is the spec's regex
  scanner (identical output to the Python port); apps can plug in a platform
  ICU break iterator for dictionary-based Chinese, Japanese and Thai breaks
  without touching the algorithm.
- A Flutter recipe (`docs/recipes/flutter.md`): `SmoothText` widget,
  selectable variant, and an ICU segmenter over a platform channel.

### Parity fixes (algorithm and markup)

- Kotlin: out-of-range `fixation`, `saccade` and `minWordLength` are clamped
  instead of throwing, as the spec and every other port already did.
- Kotlin: CDATA sections and unterminated comments pass through exactly as in
  the TypeScript core; previously the markup could be corrupted.
- Swift: the default (no `locale`) path now uses the same dictionary-based
  word breaker as the explicit-locale path, so Chinese and Japanese are
  broken into words by default as in every other port.
- Swift: an empty `className` emits `class=""` like the other ports.
- Tag names follow one grammar in every port (the TypeScript rule: a name
  runs to whitespace, `/` or `>`; `</ code>` closes; `<code / >` self-closes).
- Regex-fallback tokenizers (TypeScript without `Intl.Segmenter`, Python,
  Kotlin's `SpecWordSegmenter`, Dart) share one run rule: a continuous run of
  Han, Kana, Hangul, Thai, Lao, Khmer or Myanmar characters is one word,
  split from adjacent text of other scripts (`iPhone手机` → `iPhone` +
  `手机`), with combining marks attached. The table of code-point ranges is
  now in the spec.
- Python: non-integer numeric options are truncated then clamped instead of
  raising, matching the TypeScript core.

### Fixtures and spec

- New `fixtures/common` cases for option clamping, CDATA, unterminated
  comments, the tag-name grammar and script-boundary splitting; every port
  passes them.
- `docs/SPEC.md` documents the known, accepted differences between ICU word
  breaking and the regex fallback (`3.14`, `1,000`, `snake_case`, `½`, Khmer
  coeng clusters) and the optional break-iterator hook.

### Release engineering

- `release.yml` publishes `smooth_reading` to pub.dev (automated publishing)
  and verifies the Dart version; `ci.yml` tests Dart 3.0.0 and stable.
- npm now publishes under the `latest` dist-tag; PyPI as a normal release.

## 0.1.0-rc.2 — 2026-09-10

Android artifacts move to the Maven group `io.github.pythonshe` (the Kotlin
package stays `io.smoothreading`). No algorithm or API changes; npm and PyPI
are republished under the new version for consistency.

## 0.1.0-rc.1 — 2026-09-10

Release candidate: the first published build of every port, for integration
testing ahead of 0.1.0. npm publishes under the `next` dist-tag, PyPI as
`0.1.0rc1`, Maven Central as `0.1.0-rc.1`, SwiftPM from the `v0.1.0-rc.1` tag.

Initial release of the guided fixation reading algorithm specified in
`docs/SPEC.md`, with one first-party port per platform runtime and identical
output across all of them.

### Ports

- `@smooth-reading/core` (TypeScript, npm): `tokenize`, `toHtml`,
  `applyToElement` with restore, `createTransformStream`, `fixationLength`,
  `defaults`, `defaultSkipTags` and `styles.css`. Word breaking uses
  `Intl.Segmenter` when available and the spec regex otherwise.
- `SmoothReading` (Swift Package, iOS 15+/macOS 12+/watchOS 8+/tvOS 15+/
  visionOS 1+): `NSAttributedString` with real bold fonts plus `UILabel`,
  `UITextView`, `NSTextField` and `NSTextView` helpers, `AttributedString` for
  SwiftUI, `html()` and `tokenize()`. ICU word breaking via
  `enumerateSubstrings(.byWords)` and `CFStringTokenizer` for a locale.
  Resolvable from the repository root via SwiftPM.
- `io.github.pythonshe:smooth-reading` (Kotlin, minSdk 24): pure-JVM
  `smooth-reading-core` plus `spanned()` for `TextView` and
  `annotatedString()` for Compose, ICU `BreakIterator` word breaking.
- `smooth-reading` (Python 3.10+, PyPI): `tokenize`, `to_html`, `to_markdown`
  and the `smooth-reading` CLI; regex-equivalent tokenizer with no
  dependencies.

### Algorithm and options

- Fixation strength 1–5 with the ratio table 0.20 / 0.35 / 0.50 / 0.65 / 0.80,
  round-half-up, clamped to `1…n` grapheme clusters; `saccade`,
  `minWordLength`, `emphasizeNumbers`, `locale` and a `fixationLength`
  override.
- Out-of-range `fixation` and `saccade` are clamped into range in every port.
- HTML rendering passes existing tags and character references through,
  never emphasises text inside `code`, `pre`, `script`, `style`, `kbd`,
  `samp` or `textarea`, never nests emphasis, and emits neutral markup styled
  by CSS custom properties.

### Fixtures

- Shared JSON fixtures under `fixtures/common/` (basic, edge cases, markup,
  options, saccade, scripts) that every port must pass, and
  `fixtures/segmenter/` (CJK, extended CJK, bidi) for ports with an ICU word
  breaker. Every port also checks that token texts concatenate back to the
  input and that the markup with emphasis tags stripped equals the escaped
  input.

### Languages

- Chinese, Japanese, Korean, Thai, Vietnamese, Hindi and other Indic
  scripts, Arabic, Hebrew, Persian and Urdu are first-class: dictionary-based
  word breaks where ICU provides them, grapheme-cluster counting so combining
  marks, Indic conjuncts, Thai vowel signs, Hangul jamo and emoji sequences
  are never split, and bidi ordering is never altered. Details and known
  engine differences are in `docs/LANGUAGES.md`.

### Documentation

- `docs/SPEC.md` (the contract), `docs/LANGUAGES.md`, copy-paste framework
  recipes in `docs/recipes/` (React, Vue, Svelte, Angular, React Native,
  web component, Markdown pipelines) and a Vite playground in
  `examples/playground/`.
