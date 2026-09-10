# Changelog

All notable changes to this project are documented here. Versions are bumped
together across all four ports and releases are tagged `vX.Y.Z`.

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
- `io.smoothreading:smooth-reading` (Kotlin, minSdk 24): pure-JVM
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
