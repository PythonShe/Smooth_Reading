# Smooth Reading — Core Specification

Smooth Reading is an open-source (Apache-2.0) implementation of *guided fixation reading*:
the first part of every word is emphasised (usually bold) so the eye has an
artificial fixation point and the brain completes the rest of the word.
The technique is popularly known under a trademarked commercial name; this
project does not use that name and is not affiliated with it.

This document is the contract every package in the monorepo must follow.
The core algorithm is deterministic and language-agnostic so that ports
(TypeScript, Python, Swift, …) produce byte-identical output for the shared
fixtures in `fixtures/`.

## 1. Terminology

| Term | Meaning |
| --- | --- |
| **word** | A maximal run of letters/digits/marks, optionally joined by apostrophes, as segmented by the tokenizer (see §3). Hyphens are separators, so `text-vide` is two words. |
| **fixation** | The emphasised prefix of a word. |
| **fixation strength** | Integer 1–5 controlling how much of each word is emphasised. Default **3**. |
| **saccade** | Which words get a fixation. `saccade = 1` → every word, `2` → every second word, … Default **1**. |
| **token** | A piece of the input: either a word (with a computed split index) or a separator (whitespace, punctuation, HTML tag). |

## 2. Fixation length algorithm

Given a word of `n` *user-perceived characters* (grapheme clusters, not UTF-16 code units) and fixation strength `s ∈ {1,2,3,4,5}`:

```
ratio     = { 1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80 }[s]
prefixLen = clamp( round_half_up(n * ratio), 1, n )   // for n >= 1
```

Special cases. Suppression rules are evaluated first; if any of them applies the word gets **no** fixation (`prefixLen = 0`). Only then does the single-character rule apply, and finally the ratio formula:

1. Suppression: words consisting entirely of digits are not emphasised unless `emphasizeNumbers` is `true`.
2. Suppression: words with fewer than `minWordLength` graphemes (default `1`) are not emphasised.
3. `n == 1` → the single character is emphasised **only if** `s >= 3`. This applies to every script, including single-character CJK words produced by the segmenter (e.g. 我 at strength 2 gets no fixation).
4. Otherwise `prefixLen = clamp(round_half_up(n * ratio), 1, n)`.
5. Apostrophes inside a word count as characters (e.g. `don't` n=5 → prefix `don`). Hyphens split words, so `well-known` → `<b>we</b>ll-<b>kno</b>wn` (`known` is 5 graphemes, 2.5 rounds up to 3).

A word that receives no fixation still consumes a saccade index (§4) and is emitted as plain text, never wrapped in `restTag`.

`round_half_up(x)` means `floor(x + 0.5)`. To avoid floating-point drift, ports compute it in integer arithmetic as `floor((n * percent + 50) / 100)` with `percent ∈ {20, 35, 50, 65, 80}`. Ports must use this exact rounding (not banker's rounding) so results are identical across languages.

Examples at default strength 3:

| word | n | prefix |
| --- | --- | --- |
| a | 1 | **a** |
| to | 2 | **t**o |
| the | 3 | **th**e |
| read | 4 | **re**ad |
| smooth | 6 | **smo**oth |
| reading | 7 | **read**ing |
| 2024 | 4 | (none) |
| naïve | 5 | **naï**ve |

An **override function** may replace the algorithm entirely (all special cases included; the result is clamped to `0..n`):
`fixationLength(word: string, graphemeCount: number, options) => number`.

## 3. Tokenizer

* Prefer `Intl.Segmenter(locale, { granularity: "word" })` when available; it yields dictionary-based word breaks for Chinese, Japanese and Thai and correct handling for every Unicode script. Segments with `isWordLike === true` are words; the rest are separators.
* Fallback (no `Intl.Segmenter`, and all non-JS ports) — a Unicode-aware regular expression:
  `[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*`
  This mirrors ICU's default word-break rules for Latin-like text (apostrophe joins, hyphen splits), so `Intl.Segmenter` and the regex produce identical tokens for every `common` fixture. A word never starts with a combining mark: a mark that follows a separator — the variation selector of an emoji such as `❤️` — belongs to that separator, as in ICU (UAX #29 WB4), so `I ❤️ you` emits `❤️` untouched. `common` fixtures avoid inputs where ICU and the regex are known to differ (decimal numbers such as `3.14`, underscores, emoji).
  Runs of CJK ideographs (`\p{Script=Han}`, Hiragana, Katakana, Hangul) and Thai are treated as one word per **run**, and the uniform §2 rules apply to that run. Ports document which tokenizer they use; fixtures are split into `fixtures/common/*` (must match in every port) and `fixtures/segmenter/*` (only required when `Intl.Segmenter` is used).
* The `locale` option (BCP-47 string, default `undefined` → runtime default) is passed straight to the segmenter.
* Grapheme clusters are counted with `Intl.Segmenter(locale, { granularity: "grapheme" })` when available, or with the platform's UAX #29 extended-grapheme-cluster engine (`Character` in Swift, `BreakIterator.getCharacterInstance()` on the JVM). Those engines must implement at least **Unicode 15.1** grapheme rules: Hangul jamo sequences compose into syllables (GB6–GB8) and Indic conjuncts link (GB9c) — a consonant, a virama and the following consonant of Devanagari, Bengali, Gujarati, Oriya, Telugu or Malayalam are one cluster, so `क्ष` is never split by a fixation. Otherwise ports use the same approximation: a code point plus any following combining marks (general categories `Mn`, `Mc`, `Me`) is one cluster, a ZWJ (U+200D) joins the next code point, Hangul jamo compose (L* (V+ | LV | LVT) T*), a consonant followed by `marks* virama marks* consonant` of the six scripts above links into one cluster (the exact linker and consonant sets are the Unicode 15.1 `Indic_Conjunct_Break` values), and CR LF is one cluster. Combining marks therefore never get split from their base on either path, and `common` fixtures such as decomposed `naïve`, decomposed Hangul and `क्षत्रिय` pass everywhere. Unicode 17 extends conjunct linking to further scripts (Khmer coeng, Myanmar virama, Tai Tham, Balinese, Sundanese); engines currently disagree about those, so the approximation does not apply them and fixtures avoid such sequences (see `docs/LANGUAGES.md`).

## 4. Public API (core)

```ts
export interface SmoothOptions {
  fixation?: 1 | 2 | 3 | 4 | 5;        // default 3
  saccade?: number;                     // default 1, integer >= 1
  minWordLength?: number;               // default 1
  emphasizeNumbers?: boolean;           // default false
  locale?: string;                      // BCP-47
  fixationLength?: FixationLengthFn;   // (word, graphemes, opts: ResolvedSmoothOptions) => number; result truncated and clamped to 0..graphemes
}

export type Token =
  | { type: "word"; text: string; fixation: number /* graphemes */; fixationText: string; restText: string }
  | { type: "separator"; text: string };

export function tokenize(text: string, options?: SmoothOptions): Token[];

export interface HtmlOptions extends SmoothOptions {
  tag?: string;                         // default "b"
  className?: string;                   // default undefined → no class attribute
  restTag?: string;                     // default undefined → rest is plain text
  restClassName?: string;
  ignoreHtmlTags?: boolean;             // default true: text inside <...> is not touched
  skipTags?: string[];                  // default ["code","pre","script","style","kbd","samp","textarea"]
}
export function toHtml(text: string, options?: HtmlOptions): string;

// Browser only. Walks text nodes, wraps fixations, skips `skipTags` and
// elements matching `skipSelector`. Returns a restore() function.
export function applyToElement(root: Element, options?: DomOptions): () => void;

export interface ResolvedSmoothOptions { fixation: 1|2|3|4|5; saccade: number; minWordLength: number; emphasizeNumbers: boolean; locale: string | undefined; fixationLength: FixationLengthFn | undefined }
export const defaults: ResolvedSmoothOptions;
```

Rules:

* `toHtml` escapes `<`, `>`, `&`, `"` in **text** it emits. Existing tags are passed through verbatim when `ignoreHtmlTags` is `true`.
* `saccade` counts **word** tokens only; the first word of the input always gets a fixation (index 0 mod saccade).
* Every word token consumes a saccade index, including numbers, words below `minWordLength` and single letters below strength 3. Text inside `skipTags` is never tokenised and consumes nothing.
* When `ignoreHtmlTags` is `true`, the emphasis `tag` and `restTag` themselves are implicitly added to `skipTags`, so already-emphasised markup is never nested: `<b>Smooth</b> reading` → `<b>Smooth</b> <b>read</b>ing`. Full idempotence of `toHtml(toHtml(x))` is **not** guaranteed, because the un-emphasised remainder of a word is plain text and gets emphasised on the second pass. `applyToElement` is idempotent: it marks the wrappers it creates and skips them on re-application.
* Entities: with `ignoreHtmlTags: true`, existing character references (`&amp;`, `&#x27;`, …) are passed through verbatim and act as word boundaries; a bare `&` that does not start a reference is escaped. With `ignoreHtmlTags: false`, every `&` is escaped. A `<` only starts markup when followed by a letter, `/`, `!` or `?`; otherwise it is text and escaped. A tag or processing instruction ends at the **first** `>` (quoted attribute values are not parsed); a comment `<!--` ends at the first `-->` and a CDATA section `<![CDATA[` at the first `]]>`, both may contain `>`. An unterminated `<` construct is text. A malformed reference such as `&#;` or `&#x;` is not a reference: the `&` is escaped and what follows is ordinary text (so the `x` in `&#x;` is a word).
* `toHtml` output is deterministic: the same input and options always produce the same string.

## 5. CSS

Emphasis is purely presentational, so the core emits semantic-neutral markup and ships an optional stylesheet, `packages/core/styles.css`:

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

Consumers who prefer no bold may set `tag: "span"`, `className: "sr-fixation"` and style it themselves (colour, weight 600, underline…).

## 6. First-party ports

The project ships one package per platform runtime. Framework adapters (React, Vue, Svelte, …) are deliberately **not** published: they are 10–20 line wrappers around `tokenize` and live as copy-paste recipes in `docs/recipes/`.

| Package | Runtime | Export |
| --- | --- | --- |
| `@smooth-reading/core` (npm) | Web, Node, Bun, Deno, React Native | `tokenize`, `toHtml`, `applyToElement`, `createTransformStream`, `styles.css` |
| `SmoothReading` (Swift Package) | iOS 17+, macOS 14+ | `tokenize`, `nsAttributedString(_:options:)` → `NSAttributedString` for UIKit/AppKit (primary), `attributedString(_:options:)` → `AttributedString` for SwiftUI, `html(_:options:)` |
| `io.smoothreading:smooth-reading` (Maven) | Android (minSdk 26), JVM | `tokenize`, `annotatedString()` for Compose, `spanned()` for `TextView`, `toHtml()` |
| `smooth-reading` (PyPI) | Python 3.10+ | `tokenize`, `to_html`, CLI |

Every port passes `fixtures/common/*`. Ports whose runtime has a Unicode word-break engine (ICU on Apple platforms via `NSLinguisticTagger`/`String.enumerateSubstrings(.byWords)`, `android.icu.text.BreakIterator` on Android, `Intl.Segmenter` in JS) should use it and also pass `fixtures/segmenter/*`; Python uses the regex fallback only.

## 7. Fixtures

`fixtures/common/*.json` is an array of cases:

```json
{ "name": "basic", "input": "Smooth reading works.", "options": { "fixation": 3 },
  "html": "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks." }
```

Every port must pass every `common` fixture with the default `tag: "b"`. Segmenter-only fixtures live in `fixtures/segmenter/`.

## 8. Non-goals

* No network calls, no telemetry, no runtime dependencies in `core`.
* No claim of scientific efficacy in docs beyond citing published studies neutrally.
