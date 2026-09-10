# smooth_reading

Guided fixation reading for Dart and Flutter: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this package is an independent, clean-room, zero-dependency Apache-2.0 implementation. The algorithm is formally defined in [`docs/SPEC.md`](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/SPEC.md), guaranteeing deterministic, byte-identical output with the TypeScript, Swift, Kotlin and Python ports across all shared fixtures.

- **Dart 3.0+**, pure Dart: runs in Flutter on every platform (iOS, Android, web, macOS, Windows, Linux), on the server and in the browser.
- **Zero runtime dependencies**: only `dart:core`.
- **Flutter-ready tokens**: `tokenize()` returns a sealed `Token` hierarchy that maps straight onto `TextSpan` children; no HTML parsing, no `Html` widget.
- **Unicode-aware**: diacritics, combining marks, Hangul jamo, Indic conjuncts, contractions, right-to-left scripts and emoji sequences are never split.
- **Pluggable segmenter**: plug in a platform ICU break iterator for dictionary-based Chinese, Japanese and Thai word breaks without changing the algorithm.

---

## Installation

```bash
dart pub add smooth_reading
# or, in a Flutter project
flutter pub add smooth_reading
```

---

## Examples

### 1. Flutter: render with `TextSpan`

```dart
import 'package:flutter/widgets.dart';
import 'package:smooth_reading/smooth_reading.dart';

class SmoothText extends StatelessWidget {
  const SmoothText(this.text, {super.key, this.options = SmoothOptions.defaults});

  final String text;
  final SmoothOptions options;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final token in tokenize(text, options))
            switch (token) {
              WordToken(fixation: > 0, :final fixationText, :final restText) =>
                TextSpan(children: [
                  TextSpan(text: fixationText, style: bold),
                  TextSpan(text: restText),
                ]),
              WordToken(:final text) || SeparatorToken(:final text) =>
                TextSpan(text: text),
            },
        ],
      ),
    );
  }
}
```

Usage: `SmoothText('Smooth reading works.', options: SmoothOptions(fixation: 4))`. The widget is a pure function of its inputs, so it works with `const` options, `SelectableText.rich`, and any text direction (RTL text stays RTL: the fixation is always the logical start of the word). The full recipe, including a `SelectableText` variant and an ICU segmenter over a platform channel, is in [`docs/recipes/flutter.md`](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/recipes/flutter.md).

### 2. Render HTML

```dart
import 'package:smooth_reading/smooth_reading.dart';

toHtml('Smooth reading works.');
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
```

### 3. Configure strength, saccade interval and CSS classes

```dart
// Emphasise every 2nd word at strength 5:
toHtml('Smooth reading works.',
    options: const SmoothOptions(fixation: 5, saccade: 2));
// '<b>Smoot</b>h reading <b>work</b>s.'

// Style with semantic spans and classes:
toHtml('Smooth reading',
    tag: 'span', className: 'sr-fixation',
    restTag: 'span', restClassName: 'sr-rest');
// '<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> <span class="sr-fixation">read</span><span class="sr-rest">ing</span>'
```

Pair with the core package stylesheet:

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

### 4. Work directly with tokens

```dart
for (final token in tokenize('Smooth reading', const SmoothOptions(fixation: 4))) {
  if (token case WordToken(:final fixationText, :final restText)) {
    print('$fixationText | $restText');
  }
}
// Smoo | th
// readi | ng
```

`Token` is a sealed class with two cases, `WordToken` (`text`, `fixation`, `fixationText`, `restText`, where `fixationText + restText == text`) and `SeparatorToken` (`text`). Concatenating `token.text` over the list gives the input back unchanged.

### 5. Render Markdown

```dart
toMarkdown('Smooth reading works.');
// '**Smo**oth **read**ing **wor**ks.'
```

---

## HTML parsing and markup handling

By default (`ignoreHtmlTags: true`) `toHtml` treats the input as HTML:

- Existing tags, comments and character references (`&amp;`, `&#x27;`) pass through untouched and act as word boundaries.
- Text inside `skipTags` elements (`code`, `pre`, `script`, `style`, `kbd`, `samp`, `textarea`) is never altered.
- The fixation `tag` and `restTag` are added to the skip list automatically, so already-emphasised markup is never wrapped twice.
- Emitted text has `& < > "` escaped.

```dart
toHtml('<p>Smooth reading</p> <code>x = 1</code> <b>done</b> & gone');
// '<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code> <b>done</b> &amp; <b>go</b>ne'
```

Pass `ignoreHtmlTags: false` to treat the input as plain text and escape every HTML character:

```dart
toHtml('Tom & Jerry <3', ignoreHtmlTags: false);
// '<b>To</b>m &amp; <b>Jer</b>ry &lt;3'
```

---

## Configuration options

`SmoothOptions` has a `const` constructor; out-of-range `fixation` (outside 1–5), `saccade` (< 1) and `minWordLength` (< 0) are clamped into range rather than rejected.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `int` 1..5 | `3` | Ratio of the word emphasised: `0.20, 0.35, 0.50, 0.65, 0.80`. |
| `saccade` | `int >= 1` | `1` | Emphasise every *N*-th word. |
| `minWordLength` | `int >= 0` | `1` | Words shorter than this get no fixation. |
| `emphasizeNumbers` | `bool` | `false` | Whether words made only of decimal digits are emphasised. |
| `locale` | `String?` | `null` | BCP-47 tag, passed to the `segmenter`; the built-in one ignores it. |
| `fixationLength` | `FixationLengthFn?` | `null` | Custom `(word, graphemes, options) => int` replacing the fixation calculation. |
| `segmenter` | `Segmenter` | `SpecSegmenter()` | Source of word boundaries and grapheme clusters (see below). |

`toHtml` additionally accepts `tag`, `className`, `restTag`, `restClassName`, `ignoreHtmlTags` and `skipTags`; `toMarkdown` accepts `marker` (default `**`).

---

## Algorithm

For a word of `n` grapheme clusters and strength `s`:

```
ratio     = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}[s]
prefixLen = clamp(floor(n * ratio + 0.5), 1, n)
```

Rules are applied in order:

1. Words made only of digits are skipped unless `emphasizeNumbers` is `true`.
2. Words shorter than `minWordLength` are skipped.
3. A single-character word is emphasised only when `s >= 3`.
4. Otherwise `prefixLen` is computed with integer half-up rounding, `floor((n * percent + 50) / 100)`.

`fixationLength(word, graphemes, options)` is exported so a custom override can delegate to it.

---

## Tokenizer, Unicode and the `Segmenter` interface

Dart's standard library has no ICU break iterator, so the default `SpecSegmenter` is the spec's regular-expression scanner, implemented with Dart's Unicode-aware `RegExp` (`\p{L}`, `\p{N}`, `\p{M}`). It produces exactly the same output as the Python port:

- **Word boundaries**: maximal runs of letters, numbers and marks, optionally joined by internal apostrophes (`don't` is one word; `well-known` splits at the hyphen). A word never starts with a combining mark; a mark following a separator (the variation selector in `❤️`) stays with the separator.
- **Grapheme clusters**: a UAX #29 approximation with no dependencies. Base characters plus combining marks form one cluster, a ZWJ joins the next character, decomposed Hangul jamo compose into syllables, Indic conjuncts of the Unicode 15.1 linker scripts (Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam, e.g. `क्ष`) stay whole, and CR LF is one cluster.
- **Scripts without spaces**: each unbroken run of Han, Kana or Hangul is one word (`我喜欢阅读` → `<b>我喜欢</b>阅读`), and a run is split from adjacent Latin text (`iPhone手机` → `iPhone` + `手机`), matching how ICU breaks script boundaries.

All space-separated scripts (Latin, Greek, Cyrillic, Korean, Vietnamese, Indic scripts, Arabic, Hebrew, Persian, Urdu) render byte-identically to the ICU-backed ports; the package passes every case in `fixtures/common/`, including `scripts.json`.

### Dictionary word breaks for Chinese, Japanese and Thai

Implement `Segmenter` on top of a platform break iterator and pass it in options. The algorithm, saccade counting and HTML rendering are unchanged; only the boundary source differs.

```dart
final class IcuSegmenter extends Segmenter {
  const IcuSegmenter(this.breakWords);

  /// e.g. a MethodChannel call into android.icu.text.BreakIterator or
  /// NSString.enumerateSubstrings(.byWords), returning (text, isWord) pairs.
  final List<(String, bool)> Function(String text, String? locale) breakWords;

  @override
  List<Segment> segmentWords(String text, String? locale) => [
        for (final (chunk, isWord) in breakWords(text, locale))
          Segment(chunk, isWord: isWord),
      ];

  @override
  List<String> graphemes(String text, String? locale) =>
      const SpecSegmenter().graphemes(text, locale); // or package:characters
}

tokenize(text, SmoothOptions(locale: 'zh', segmenter: IcuSegmenter(myBridge)));
```

For the detailed cross-platform comparison see [`docs/LANGUAGES.md`](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/LANGUAGES.md).

---

## Development

```bash
cd dart
dart pub get
dart analyze
dart test
dart format --set-exit-if-changed .
```

The tests run the shared `fixtures/common/*.json` suite from the repository root and the lossless/bidi invariants over `fixtures/segmenter/*.json` as well.

---

## License

Apache-2.0. See [LICENSE](LICENSE).
