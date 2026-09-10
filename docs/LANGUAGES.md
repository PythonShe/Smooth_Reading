# Languages and scripts

CJK, the other Asian scripts and right-to-left text are the reason this
library exists. This document is the support matrix behind the summary in the
root `README.md`: which engine breaks words and counts grapheme clusters in
each port, what the fixtures prove, where the engines are known to disagree,
and how the fixtures were chosen so that every port passes them.

The algorithm itself is script-agnostic (`docs/SPEC.md`): a word is emphasised
on its first `round_half_up(n × ratio)` *grapheme clusters*. Everything
script-specific therefore lives in two places — the **word breaker** (what is a
word?) and the **grapheme engine** (what is one user-perceived character?).

## Engines per port

| Port | Word breaker | Grapheme clusters |
| --- | --- | --- |
| `@smooth-reading/core` (JS) | `Intl.Segmenter(locale, { granularity: "word" })` — the JS engine's ICU (V8 with full ICU, JavaScriptCore, ICU4X in Firefox); the SPEC §3 regex when `Intl.Segmenter` is missing | `Intl.Segmenter(…, { granularity: "grapheme" })`; the SPEC §3 approximation as fallback |
| Swift | ICU via `String.enumerateSubstrings(.byWords)`, or `CFStringTokenizer` when a `locale` is set | Swift `Character` (the stdlib's UAX #29 implementation, Unicode 16 in Swift 6.3) |
| Android | `android.icu.text.BreakIterator` (`IcuWordSegmenter`, default for `annotatedString()` / `spanned()`), or `SpecWordSegmenter` (the SPEC §3 regex plus the run rule) | `java.text.BreakIterator.getCharacterInstance()` — ICU-backed on a device, the JDK's rule set in JVM unit tests |
| Python | hand-written scanner equivalent to the SPEC §3 regex plus the run rule; no dictionary | the SPEC §3 approximation (`smooth_reading.graphemes`) |

**ICU dictionary breaking** — real word boundaries for Chinese, Japanese,
Thai, Lao, Khmer and Burmese — is available in the core (with
`Intl.Segmenter`), Swift and Android (`IcuWordSegmenter`). The regex ports
(Python, Android's `SpecWordSegmenter`, the core fallback) treat each run of
Han, kana, Hangul or Thai as a single word and apply the uniform rules to it:
`我喜欢阅读` is one five-character word with a three-character fixation instead
of `我 | 喜欢 | 阅读`. That is deliberate — predictable, dependency-free — and it
is why `fixtures/segmenter/` is only required of the ICU ports.

## Support matrix

Status values: **identical** = every port produces byte-identical output and
the fixtures prove it; **ICU** = correct word breaks in the ICU ports, run rule
elsewhere; **engine-dependent** = ICU builds disagree with each other, the
fixtures avoid the disputed inputs and the notes say what to expect.

| Script | core | Swift | Android | Python | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Latin (incl. Vietnamese, Turkish `İ`/`ı`, German `ß`, long compounds) | ICU / regex | ICU | ICU / regex | regex | identical | NFC and NFD Vietnamese count the same; `İstanbul'da` is one word (apostrophe joins) |
| Greek (monotonic and polytonic), Cyrillic | ICU / regex | ICU | ICU / regex | regex | identical | precomposed and decomposed breathings both count once |
| Korean, Hangul with spaces | ICU / regex | ICU | ICU / regex | regex | identical | decomposed jamo (`ᄒ ᅡ ᆫ`) compose to one cluster in every port |
| Korean without spaces | ICU | ICU | ICU | regex | identical | ICU has no Hangul dictionary either: `한국어문장` is one word everywhere |
| Chinese, Simplified | dictionary | dictionary | dictionary | run rule | ICU | `locale: "zh"` |
| Chinese, Traditional | dictionary | dictionary (`zh-Hant`) | dictionary | run rule | ICU | in Swift pass `locale: "zh-Hant"` (or none): `CFStringTokenizer` with plain `zh` splits `我們`/`學習` into single characters |
| Japanese | dictionary | dictionary | dictionary | run rule | ICU, engine-dependent inflections | particles are separate words (`私 は 本 を`); loanwords split at morpheme boundaries (`スマート フォン`); `「」` are separators; verb endings differ between ICU builds (see below) |
| Thai | dictionary | dictionary | dictionary | run rule | ICU, engine-dependent compounds | vowel signs and tone marks stay with their consonant; compounds such as `ภาษาไทย` are one word on Apple ICU and two in ICU 76+ |
| Lao | dictionary | dictionary | dictionary | run rule | ICU | `ພາສາ ລາວ ງ່າຍ` on every engine tested |
| Khmer | dictionary | dictionary | dictionary | run rule | ICU, engine-dependent clusters | dictionary words agree; consonant + coeng (U+17D2) + consonant is one cluster in ICU 76+/JDK 26 (Unicode 17) but two in Swift 6.3 — fixtures avoid coeng stacks |
| Burmese | dictionary | dictionary | dictionary | run rule | ICU | spacing vowel signs such as `ာ` (U+102C) are their own cluster per UAX #29, on every engine; the Python approximation attaches them |
| Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam | ICU / regex | ICU | ICU / regex | regex | identical (Unicode ≥ 15.1) | conjuncts link (GB9c): `क्षत्रिय` = `क्ष | त्रि | य`; JDK 21 (Android unit tests) still splits after the virama — see *Known gaps* |
| Tamil, Sinhala, other Indic scripts without the linker property | ICU / regex | ICU | ICU / regex | regex | identical | virama/pulli stays with its consonant; no linking (`தமிழ்` = 3 clusters). Kannada's linker was added in Unicode 16 and is engine-dependent; not in the fixtures |
| Arabic, Persian, Urdu | ICU / regex | ICU | ICU / regex | regex | identical | tashkeel and shadda stay with their letter; Arabic-Indic digits are numbers; Persian ZWNJ (U+200C) keeps a word together only in the ICU ports (`می‌خواهم`), the regex splits at it |
| Hebrew | ICU / regex | ICU | ICU / regex | regex | identical | niqqud and the shin/sin dots stay with their letter; geresh/gershayim inside words (`צ׳ילה`) are joined by ICU but split by the regex — not in the fixtures |
| Digits of any script (`\p{Nd}`: `42`, `٤٢`, `४२`) | — | — | — | — | identical | numbers get no fixation unless `emphasizeNumbers`, but still consume a `saccade` index |
| Emoji, skin-tone modifiers, ZWJ sequences, variation selectors | — | — | — | — | identical | separators, passed through untouched; a lone U+FE0F after an emoji belongs to the separator |
| Full-width Latin (`ＨＥＬＬＯ`) | ICU / regex | ICU | ICU / regex | regex | identical | ordinary letters |

## Per-script rationale

**Chinese, Japanese, Thai, Lao, Khmer, Burmese.** These scripts write words
without spaces, so a fixation per *word* requires a dictionary. Every ICU
build ships one, and all three ICU ports use it. The regex rule (one word per
run) is the honest fallback: it never splits inside a word, it just makes the
"word" too long. Single-character words (`我`, `は`) follow the ordinary
single-character rule — emphasised at strength ≥ 3, plain below — so the
default strength reads as "every word starts bold" in Japanese too.

**Korean.** Hangul is written with spaces, so the regex ports are as good as
ICU here. The jamo case matters for text from older systems and from NFD
normalisation (macOS file names, some databases): a syllable spelled as
`L V T` jamo must count as one character, or a fixation of length 1 would
land between the consonant and its vowel. All four ports compose jamo.

**Indic scripts.** A consonant cluster such as `क्ष` (`क` + virama + `ष`) is
one visual unit; splitting it between `<b>` and plain text breaks the ligature
and shows a dangling half-form. Unicode 15.1 added rule GB9c to UAX #29 for
exactly this reason, and it is now the behaviour of `Intl.Segmenter` (ICU 74+),
Swift's `Character` (Swift 6+), ICU-backed Android and JDK 22+. The Python
port and the core fallback implement the same rule with the Unicode 15.1
linker and consonant tables (six scripts). Bold is a poor emphasis for these
scripts in many fonts; use colour (see the root README).

**Arabic script and Hebrew.** Combining vowel points never occur alone, so the
regex and ICU agree. The one difference is Persian's ZWNJ, which ICU treats as
part of the word (UAX #29 `Extend`) and the regex treats as a separator; the
`segmenter/bidi.json` fixture pins the ICU behaviour. Note that bold Arabic is
often typographically unconvincing (Naskh faces with a single weight, or bold
that merely thickens strokes); prefer colour or a different weight via
`className`.

**Digits.** Suppression rule 1 in SPEC §2 is defined on `\p{Nd}`, so digit
systems of every script — European `42`, Arabic-Indic `٤٢`, Devanagari `४२` —
are numbers: no fixation by default, a fixation of the usual length with
`emphasizeNumbers`, and they always consume a `saccade` index. Roman numerals
and vulgar fractions are not `Nd` and are treated as words.

**Emoji.** Neither the regex nor ICU makes a word out of an emoji, a skin-tone
modifier, a ZWJ sequence or a variation selector, so they pass through as
separators. The regex rule that a word never *starts* with a combining mark is
what keeps `❤️`'s U+FE0F attached to the heart instead of becoming a
one-character word.

## Bidirectional text

The fixation is the logical start of every word — the characters read first —
so Arabic and Hebrew words are emphasised on their right-hand edge without any
direction-specific code. Three guarantees follow from that:

1. **No direction changes.** The HTML renderers never emit `dir` attributes,
   `<bdi>`/`<bdo>` wrappers or bidi control characters (LRM, RLM, ALM, the
   embeddings, overrides and isolates), and the attributed-string renderers
   never insert isolates. Whatever bidi context you pass in (`<p dir="rtl">`,
   an RLM in the text) comes out verbatim.
2. **Lossless.** Concatenating the `text` of every token — and the runs of
   every attributed string — reproduces the input exactly. Every port has a
   test that runs this over every fixture input in both suites, and a test
   that the rendered markup with the emphasis tags stripped equals the escaped
   input.
3. **Mixed direction is tested.** `Hello مرحبا world`, `שלום world`, an
   Arabic paragraph containing `Python` and `2015`, Hebrew with `ל-Berlin`,
   a nested `<span lang="en">` inside `<p dir="rtl">`, and `saccade: 2` across
   an embedded Latin word are fixtures.

## Known gaps and engine differences

These are the inputs on which engines were observed to disagree while the
fixtures were written (Node 24.18 / ICU 76, Swift 6.3 on macOS 26, JDK 21 and
26). The fixtures avoid them; the behaviour you get is whatever your runtime's
ICU does.

- **Indic conjuncts on Unicode < 15.1 engines.** `java.text.BreakIterator` in
  JDK 21 (the Android unit-test toolchain) splits `क्ष` after the virama, so
  `क्षत्रिय` counts 5 clusters instead of 3 and the fixation ends in a
  half-form. On a device, `android.icu` (Android 15+) applies GB9c. The
  `common/scripts.json` cases `Hindi: conjunct क्षत्रिय is 3 clusters` and
  `Hindi: उम्र is 2 clusters` fail on JDK 21 for this reason.
- **Khmer coeng and Myanmar virama.** Unicode 17 extends conjunct linking to
  Khmer, Myanmar, Tai Tham, Balinese and Sundanese. ICU 76 and JDK 26 apply it
  (`ខ្មែរ` = `ខ្មែ | រ`), Swift 6.3 does not (`ខ្ | មែ | រ`), and the SPEC §3
  approximation does not. Fixtures use Khmer words without coeng stacks.
- **Japanese inflections.** ICU 76 tokenises `しています` as `し | てい | ます`
  (linguistically odd: `てい` is not a morpheme) and keeps `日本語` whole; Apple's
  ICU gives `し | て | い | ます` and splits `日本 | 語`. Verb forms such as
  `飲みました` (`飲 | み | ま | した` vs `飲み | まし | た`) differ too. The
  fixtures use sentences on which both agree (`猫がテレビを見ている`,
  `私はスマートフォンで「ニュース」を読む`).
- **Thai compounds.** `ภาษาไทย` and `ประเทศไทย` are one word on Apple ICU and
  `ภาษา | ไทย`, `ประเทศ | ไทย` in ICU 76; `วันนี้` / `ดีมาก` / `กินข้าว` split
  in ICU 76 but not on Apple. The fixture uses `ฉันชอบอ่านหนังสือ`, which
  agrees.
- **Chinese two-character function words.** ICU 76 joins `他在`, `我在`, `他用`
  before a Latin brand name; Apple ICU keeps `他 | 在`. `我用iPhone 15看视频`
  agrees on both.
- **Traditional Chinese under `CFStringTokenizer`.** With `locale: "zh"` the
  Swift locale path splits `我們` and `學習` into single characters; `zh-Hant`,
  `zh-TW` and the default (no locale) path break them correctly.
- **Persian ZWNJ, Hebrew geresh, decimal numbers, underscores.** ICU joins
  them into one word; the regex does not. They live in `fixtures/segmenter/`
  (ZWNJ) or are excluded from the fixtures.
- **Burmese spacing vowels in Python.** The approximation treats every `Mc`
  mark as an extender, so `မြန်မာ` counts 3 clusters in Python and 4 in the
  ICU ports. Burmese is not in `common`.

## How the fixtures were built

Expected outputs in `fixtures/common/scripts.json`,
`fixtures/segmenter/cjk-extended.json` and `fixtures/segmenter/bidi.json` were
computed by hand from SPEC §2 (percent table, `floor((n·p + 50) / 100)`, clamp,
single-character and digit rules). Where ICU's dictionary decides the word
boundaries, the boundaries were read from `Intl.Segmenter` and checked against
Swift's tokenizer and the JDK, and only sentences on which those engines agree
were kept; where a cluster count depends on the Unicode version, the fixture
name says so. Invisible code points (combining diacritics, jamo, ZWJ/ZWNJ,
RLM, skin-tone modifiers) are written as `\uXXXX` escapes in the JSON so that
editors cannot silently normalise them.
