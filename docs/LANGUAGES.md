# Languages and scripts

International scripts, Asian writing systems, and right-to-left text are core design requirements of Smooth Reading, not afterthoughts. This document outlines the multilingual architecture behind the summary in the root `README.md`:
- Which engines handle word breaking and grapheme clustering across each port.
- The comprehensive support matrix and test fixture guarantees.
- Known differences across platform ICU implementations.
- Guidelines for selecting fonts, weights, and styling across diverse scripts.

The core fixation algorithm ([docs/SPEC.md](SPEC.md)) is intentionally script-agnostic: each word is emphasised on its leading `round_half_up(n × ratio)` *grapheme clusters*. All script-specific behavior is handled by two components: the **word segmenter** (which identifies words) and the **grapheme cluster engine** (which identifies user-perceived characters).

---

## Engines per port

| Port | Word segmenter | Grapheme cluster engine |
| --- | --- | --- |
| `@smooth-reading/core` (JS/TS) | `Intl.Segmenter(locale, { granularity: "word" })` backed by runtime ICU; spec-compliant regular expression fallback when unavailable. | `Intl.Segmenter(…, { granularity: "grapheme" })`; spec UAX #29 approximation fallback. |
| `SmoothReading` (Swift) | ICU via `CFStringTokenizer` on every path; with no `locale` the language is auto-detected (`CFStringTokenizerCopyBestStringLanguage`, language subtag only) so Chinese and Japanese get dictionary breaks by default. | Swift standard library `Character` (native UAX #29 extended grapheme clusters). |
| `io.github.pythonshe` (Android/JVM) | Android: `android.icu.text.BreakIterator` (`IcuWordSegmenter`).<br>Plain JVM: `SpecWordSegmenter` (spec-compliant scanner). | `BreakIterator.getCharacterInstance()` with post-pass for Hangul jamo composition and Indic conjunct linking (Unicode 15.1 GB9c). |
| `smooth-reading` (Python) | High-performance scanner over `unicodedata.category` implementing spec rules; run rule for CJK/Thai. | Spec-compliant UAX #29 approximation (`smooth_reading.graphemes`). |
| `smooth_reading` (Dart) | Spec regex via Dart's Unicode `RegExp` (`\p{L}`, `\p{N}`, `\p{M}`) with the same run rule as Python; a `Segmenter` interface lets Flutter apps plug in a platform ICU break iterator. | Spec-compliant UAX #29 approximation (same regex as the JS fallback). |
| `smooth-reading` (Rust) | Spec scanner over a generated Unicode general-category table (std only, no `unsafe`) with the same run rule as Python; a `Segmenter` trait lets apps plug in an ICU break iterator such as `icu_segmenter`. | Spec-compliant UAX #29 approximation (same rules as the Python port). The bundled category table is generated from Unicode 17.0.0, newer than the Unicode 16 data in CPython 3.14 and Node 24's ICU, so characters first assigned in 17.0 are letters only in Rust; no fixture depends on them. |

**ICU dictionary breaking** — finding true lexical word boundaries in scripts without spaces (Chinese, Japanese, Thai, Lao, Khmer, Burmese) — is provided in the ICU-backed ports: `@smooth-reading/core` (via `Intl.Segmenter`), Swift, and Android (`IcuWordSegmenter`). 

The pure regular expression / scanner implementations (Python, Dart, Rust, Android's `SpecWordSegmenter`, and the JS fallback) treat each continuous run of Han, Kana, Hangul, Thai, Lao, Khmer or Myanmar characters as a unified word, split from adjacent text of other scripts. This fallback is completely self-contained, predictable, and requires zero external C/ICU dependencies.

---

## Support matrix

Status definitions:
- **Identical**: Every port produces byte-identical output verified by shared fixtures (`fixtures/common/scripts.json`).
- **ICU**: Full dictionary-based segmentation in ICU-backed ports; continuous run rule in regex/scanner implementations.
- **Engine-dependent**: Underlying system ICU versions vary across operating systems; fixtures test inputs where engines agree.

| Script | `@smooth-reading/core` | Swift | Android | Python | Dart | Rust | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Latin (incl. Vietnamese, Turkish `İ`/`ı`, German `ß`, compounds) | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | NFC and NFD Vietnamese count identically; `İstanbul'da` is one word (apostrophe joins). |
| Greek (monotonic/polytonic), Cyrillic | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Precomposed and decomposed breathings both count as single clusters. |
| Korean (Hangul with spaces) | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Decomposed jamo (`ᄒ ᅡ ᆫ`) compose into single syllable clusters across all ports. |
| Korean (Hangul without spaces) | ICU | ICU | ICU | regex | regex | regex | Identical | ICU lacks a Hangul dictionary; unbroken text like `한국어문장` forms one word across all ports. |
| Chinese (Simplified) | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Pass `locale: "zh"`. |
| Chinese (Traditional) | Dictionary | Dictionary (`zh-Hant`) | Dictionary | Run rule | Run rule | Run rule | ICU | In Swift, pass `locale: "zh-Hant"` (or `nil`); plain `zh` under `CFStringTokenizer` splits common words like `我們`. |
| Japanese | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Particles separate (`私 は 本 を`); loanwords split at morphemes (`スマート フォン`); brackets (`「」`) act as separators. |
| Thai | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Vowel signs and tone marks stay attached to consonants; compound boundaries vary slightly across ICU versions. |
| Lao | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Consistent word breaks (`ພາສາ ລາວ ງ່າຍ`) across tested ICU engines. |
| Khmer | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Lexical words match; fixtures avoid coeng stacks where ICU 76+ and older engines differ on cluster counts. |
| Burmese | Dictionary | Dictionary | Dictionary | Run rule | Run rule | Run rule | ICU | Spacing vowel signs (e.g. `ာ` U+102C) form distinct clusters per UAX #29 in ICU engines. |
| Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Conjuncts link into single clusters (Unicode 15.1 GB9c): `क्षत्रिय` = `क्ष \| त्रि \| य`. Kotlin, Python, Dart and Rust enforce GB9c explicitly. |
| Tamil, Sinhala, and other Indic scripts | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Virama/pulli stays attached to base consonants; characters do not link into multi-consonant clusters. |
| Arabic, Persian, Urdu | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Tashkeel and shadda attach to base letters; Persian ZWNJ (U+200C) preserves word unity in ICU ports. |
| Hebrew | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Niqqud and shin/sin dots attach to base consonants; geresh/gershayim within words are joined by ICU. |
| Decimal digits of any script (`\p{Nd}`) | — | — | — | — | — | — | Identical | Unemphasised unless `emphasizeNumbers: true`; always consume a `saccade` index. |
| Emoji, skin-tone modifiers, ZWJ sequences | — | — | — | — | — | — | Identical | Treated as separators; passed through untouched without splitting sequences. |
| Full-width Latin (`ＨＥＬＬＯ`) | ICU / regex | ICU | ICU / regex | regex | regex | regex | Identical | Treated as standard letters. |

---

## Per-script rationale & Best practices

### Scripts without spaces (Chinese, Japanese, Thai, Lao, Khmer, Burmese)
Because these languages do not separate words with whitespace, word-level fixation requires a dictionary. Modern ICU distributions include precompiled dictionaries for these scripts. 

The fallback run rule (treating an unbroken run of Han, Kana, or Thai characters as a single word) provides a safe, dependency-free degradation: it never breaks inside a character or grapheme cluster, and single-character words (`我`, `は`) follow standard single-character rules (emphasised only at strength ≥ 3).

### Korean (Hangul)
Hangul is standardly written with spaces, allowing regex-based segmentation to achieve full parity with ICU. All ports support Hangul jamo composition: text normalized to NFD (common in macOS file systems) where syllables are stored as individual leading consonant (L), vowel (V), and trailing consonant (T) jamo is correctly counted as a single syllabic cluster.

### Indic scripts & Unicode 15.1 conjunct linking
In Indic scripts, a consonant cluster such as Devanagari `क्ष` (`क` + virama + `ष`) forms an indivisible orthographic unit (akshara). Splitting it with markup would break font ligature shaping and display a malformed virama or half-consonant.

Unicode 15.1 introduced rule **GB9c** to UAX #29 to prevent splitting consonant conjuncts linked by a virama. All Smooth Reading ports strictly adhere to rule GB9c:
- Modern ICU engines (`Intl.Segmenter`, Apple ICU, Android ICU) support GB9c natively.
- The Kotlin, Python, Dart and Rust implementations enforce GB9c programmatically for the six designated linker scripts (Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam), ensuring consistent behavior regardless of host JDK or system library versions.

### Arabic, Persian, Urdu, and Hebrew
Diacritical marks (Arabic tashkeel/harakat, Hebrew niqqud) attach to preceding base letters and never receive separate fixation splits. 

In Persian, Zero-Width Non-Joiners (ZWNJ, U+200C) frequently join morphemes within a single compound word (e.g. `می‌خواهم`). ICU-backed ports treat ZWNJ as an internal `Extend` character, keeping the compound unified.

---

## Bidirectional text (RTL)

The fixation is always the **logical** beginning of each word (the first characters read):
- Arabic and Hebrew words are naturally emphasised at their logical start, which renders on the visual right edge in RTL contexts.
- **Zero direction interference**: Output strings and markup never introduce artificial `dir` attributes, `<bdi>` tags, or bidi control characters (such as LRM, RLM, or isolates). Existing contextual markup (such as `<p dir="rtl">`) is preserved verbatim.
- **Lossless round-tripping**: Concatenating tokens or attributed string runs reconstructs the original input exactly.
- **Mixed-direction validation**: The test suite validates complex mixed-direction passages (`Hello مرحبا world`, Hebrew with embedded Latin brand names, RTL paragraphs containing numbers and URLs).

---

## Typographic recommendations

**Bold weights are often ineffective for non-Latin typography:**
- Many Arabic, Devanagari, Bengali, and Thai typefaces do not offer distinct bold weights, or rely on synthetic bolding that degrades ligature legibility and obscures delicate diacritics.
- We recommend styling fixations using semantic CSS classes or native color/opacity attributes rather than relying exclusively on bold:

```css
/* Web CSS */
.sr-fixation {
  font-weight: 600;
  color: var(--sr-fixation-color, #1d4ed8);
}
.sr-rest {
  opacity: var(--sr-rest-opacity, 0.85);
}
```

```swift
// Swift UIKit / AppKit
SmoothReading.nsAttributedString(
    text,
    fixationAttributes: [.foregroundColor: UIColor.systemBlue]
)
```

```kotlin
// Jetpack Compose
SmoothReading.annotatedString(
    text,
    fixationStyle = SpanStyle(color = MaterialTheme.colorScheme.primary),
    restStyle = SpanStyle(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)),
)
```

---

## Known platform & Engine variations

The test suite avoids ambiguous edge cases where system ICU implementations intentionally differ:
- **Japanese grammatical inflections**: Different ICU versions segment verb endings (e.g. `しています` or `飲みました`) with varying grammatical granularity. Shared fixtures test declarative sentences with agreed-upon boundaries.
- **Thai compound words**: Compounds such as `ภาษาไทย` may be treated as a single word on older Apple ICU releases and split into two words (`ภาษา` + `ไทย`) on ICU 76+. Shared test cases use sentences where segmentation is consistent across versions.
- **Unicode 17 preview scripts**: Unicode 17 proposes extending conjunct linking to Khmer coeng stacks and Myanmar viramas. ICU 76 and JDK 26 preview this behavior, whereas current Swift and earlier ICU releases do not. Fixtures avoid disputed coeng stacks.

---

## Fixture methodology

Expected test outputs in `fixtures/common/` and `fixtures/segmenter/` are verified against the mathematical specification ([docs/SPEC.md](SPEC.md)). Non-printable and combining Unicode characters (ZWJ, ZWNJ, RLM, combining marks, variation selectors) are encoded with explicit `\uXXXX` escapes in fixture JSON files to avoid unintended editor normalization.
