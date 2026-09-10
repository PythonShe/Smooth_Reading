# Smooth Reading

Open-source, framework-friendly **guided fixation reading**: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

```
Smooth reading works.   →   **Smo**oth **read**ing **wor**ks.
```

The technique is similar to commercial fixation-reading products, but this project is independent, clean-room, trademark-free and licensed under Apache-2.0. The algorithm is documented in full in [docs/SPEC.md](docs/SPEC.md) so every port produces identical output.

## Packages

| Package | Registry | Platforms |
| --- | --- | --- |
| [`@smooth-reading/core`](packages/core) | npm | Web, Node, React Native. Zero-dependency tokenizer, HTML transformer, DOM applier, streaming transform. |
| [`SmoothReading`](swift) | Swift Package Manager | iOS, macOS. `NSAttributedString` for UIKit/AppKit, `AttributedString` for SwiftUI. |
| [`io.smoothreading:smooth-reading`](android) | Maven Central | Android, JVM. `AnnotatedString` for Compose, `Spanned` for views. |
| [`smooth-reading`](python) | PyPI | Python 3.10+. Same algorithm plus a CLI. |

React, Vue, Svelte, Angular and other framework wrappers are a few lines on top of `tokenize()`; copy one from [docs/recipes](docs/recipes) rather than adding a dependency.

## Quick start

```bash
pnpm add @smooth-reading/core
```

```ts
import { toHtml } from "@smooth-reading/core";

toHtml("Smooth reading works.");
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'

toHtml("Smooth reading works.", { fixation: 5, saccade: 2, tag: "span", className: "sr-fixation" });
```

React (see [docs/recipes/react.md](docs/recipes/react.md)):

```tsx
import { tokenize } from "@smooth-reading/core";

export function SmoothText({ children, ...opts }) {
  return tokenize(children, opts).map((t, i) =>
    t.type === "word" ? <span key={i}><b>{t.fixationText}</b>{t.restText}</span> : t.text);
}
```

Swift (UIKit):

```swift
import SmoothReading
label.attributedText = SmoothReading.nsAttributedString("Smooth reading works.", options: .init(fixation: 3))
```

See each package README for the full API.

## Why another library?

Existing open-source implementations are either single-purpose string transformers, archived browser extensions, or GPL/AGPL licensed. None of them segment Chinese, Japanese or Thai correctly, keep contractions intact, render without `innerHTML`, or ship framework adapters. 

## What the evidence says

Controlled studies (Readwise 2022, Snell 2024, Možina et al. 2025) found **no reading-speed benefit** from this technique for the general population, and no controlled study has demonstrated a benefit for ADHD or dyslexic readers. Many people nevertheless report that they prefer reading this way. Treat it as a reading *preference* you can offer users, not a speed-reading feature. Sources:

- Readwise reader study, 2022, about 1,900 participants: [blog.readwise.io](https://blog.readwise.io/bionic-reading-results/).
- Snell, *Acta Psychologica* (2024): [sciencedirect.com](https://www.sciencedirect.com/science/article/pii/S0001691824001811).
- Možina, Kovačević & Blaznik, *SAGE Open* (2025), [doi:10.1177/21582440251376158](https://journals.sagepub.com/doi/10.1177/21582440251376158).
- *Attention, Perception & Psychophysics* (2025), [doi:10.3758/s13414-025-03067-w](https://link.springer.com/article/10.3758/s13414-025-03067-w).

## Design principles

- **One documented algorithm**, shared JSON fixtures, identical output across languages.
- **Unicode first**: `Intl.Segmenter` word breaking for CJK and Thai, grapheme-cluster counting, works with any script.
- **Safe by default**: skips `code`, `pre`, `kbd`, `script`, `style` and form fields; never uses `innerHTML` in framework adapters; escapes emitted text.
- **Presentation is CSS**: the transform emits neutral markup; weight, colour and opacity live in a stylesheet you control.
- **No runtime dependencies, no network, no telemetry.**

## Languages and scripts

CJK, the other Asian scripts and right-to-left text are the point of this
library, not an afterthought. Every port passes `fixtures/common/scripts.json`
(Korean, Vietnamese, Hindi, Bengali, Tamil, Arabic, Hebrew, Persian, Urdu,
Greek, Turkish, German, mixed-direction text, emoji); the ICU-backed ports
also pass `fixtures/segmenter/` (Chinese, Japanese, Thai, Lao, Khmer, Burmese,
bidi paragraphs). The full matrix and the per-script reasoning are in
[docs/LANGUAGES.md](docs/LANGUAGES.md).

| Script | `@smooth-reading/core` | Swift | Android | Python | Status |
| --- | --- | --- | --- | --- | --- |
| Latin, Greek, Cyrillic, Vietnamese, Turkish, German | `Intl.Segmenter` (regex fallback) | ICU | ICU or spec regex | spec regex | identical everywhere |
| Korean (Hangul, spaces) | same | ICU | ICU or spec regex | spec regex | identical; decomposed jamo compose in every port |
| Chinese, Japanese | `Intl.Segmenter` dictionary | ICU dictionary | `android.icu` dictionary | one word per run | dictionary breaks in ICU ports; predictable run rule in Python |
| Thai, Lao, Khmer, Burmese | `Intl.Segmenter` dictionary | ICU dictionary | `android.icu` dictionary | one word per run | as above |
| Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam | same as Latin | ICU | ICU or spec regex | spec regex | identical; conjuncts (`क्ष`) are one cluster (Unicode 15.1) — see the Android note |
| Tamil and other Indic scripts | same as Latin | ICU | ICU or spec regex | spec regex | identical; marks stay with their consonant |
| Arabic, Persian, Urdu, Hebrew | same as Latin | ICU | ICU or spec regex | spec regex | identical; tashkeel and niqqud stay with their letter; Persian ZWNJ words stay whole only in ICU ports |
| Digits of any script (`\p{Nd}`) | — | — | — | — | numbers: no fixation unless `emphasizeNumbers`, still count for `saccade` |
| Emoji, modifiers, ZWJ and variation-selector sequences | — | — | — | — | separators, passed through untouched |

**ICU dictionary breaking** (real word boundaries for Chinese, Japanese,
Thai, Lao, Khmer and Burmese) is used by the core (`Intl.Segmenter`), Swift
(`enumerateSubstrings(.byWords)` / `CFStringTokenizer`) and Android
(`android.icu.text.BreakIterator`, the default for `annotatedString()` and
`spanned()`). Python, Android's `SpecWordSegmenter` and the core's fallback
(runtimes without `Intl.Segmenter`) use the spec's regular expression, where
each run of Han, kana, Hangul or Thai is one word — predictable, but not a
dictionary. Which runtime the fixtures were verified on, and where ICU builds
disagree with one another (Japanese inflections, Thai compounds, Khmer conjunct
counts, JDK 21's grapheme rules), is spelled out in `docs/LANGUAGES.md`.

**Bold is typographically weak for some scripts.** Many Arabic, Devanagari,
Bengali and Thai fonts have no bold face or a bold that barely differs from
regular, and synthetic bold blurs conjuncts and tashkeel. Emit a class instead
of `<b>` and style it with colour, a heavier weight, or an underline:

```ts
toHtml(text, { tag: 'span', className: 'sr-fixation', restTag: 'span', restClassName: 'sr-rest' });
```

```css
.sr-fixation { color: var(--sr-fixation-color, #1d4ed8); font-weight: 600; }
.sr-rest     { opacity: var(--sr-rest-opacity, 0.85); }
```

Swift and Android take the same idea as attributes: pass `fixationAttributes`
(a colour, an underline) to `nsAttributedString` / `attributedString`, or a
`fixationStyle` such as `SpanStyle(color = …)` to `annotatedString()`; see each
package README.

**Right-to-left text.** The fixation is always the *logical* start of the
word (the first letters read), so Arabic and Hebrew words are emphasised on
their right-hand side without any special handling. The emitted markup and
attributed strings never add `dir` attributes, `<bdi>` wrappers or bidi
control characters, and never remove the ones you supplied, so the browser's
or platform's bidi algorithm sees exactly the text you passed in. Existing
`<p dir="rtl">` markup is passed through verbatim. Mixed-direction inputs
(`Hello مرحبا world`, RTL paragraphs with Latin brand names and numbers) are
part of the fixture suite, and every port has a test that the token texts
concatenate back to the input and that the output stripped of emphasis tags is
the escaped input.

## Development

```bash
pnpm install
pnpm build
pnpm test
cd python && python -m pip install -e ".[dev]" && pytest
```

## License

Apache-2.0. See [LICENSE](LICENSE).
