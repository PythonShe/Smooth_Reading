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

Special cases, applied in this order:

1. `n == 0` → no fixation (cannot happen for a word token; separators are never emphasised).
2. `n == 1` → the single character is emphasised **only if** `s >= 3`; otherwise no fixation.
3. Words that consist entirely of digits are **not** emphasised by default (`emphasizeNumbers: false`).
4. Optional `minWordLength` (default `1`): words shorter than this get no fixation.
5. Apostrophes inside a word count as characters (e.g. `don't` n=5 → prefix `don`). Hyphens split words, so `well-known` → `<b>we</b>ll-<b>kn</b>own`.

`round_half_up(x)` means `floor(x + 0.5)`. Ports must use this exact rounding (not banker's rounding) so results are identical across languages.

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

An **override function** may replace the algorithm entirely:
`fixationLength(word: string, graphemeCount: number, options) => number`.

## 3. Tokenizer

* Prefer `Intl.Segmenter(locale, { granularity: "word" })` when available; it yields dictionary-based word breaks for Chinese, Japanese and Thai and correct handling for every Unicode script. Segments with `isWordLike === true` are words; the rest are separators.
* Fallback (no `Intl.Segmenter`, and all non-JS ports) — a Unicode-aware regular expression:
  `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`
  This mirrors ICU's default word-break rules for Latin-like text (apostrophe joins, hyphen splits), so `Intl.Segmenter` and the regex produce identical tokens for every `common` fixture. `common` fixtures avoid inputs where ICU and the regex are known to differ (decimal numbers such as `3.14`, underscores, emoji).
  Runs of CJK ideographs (`\p{Script=Han}`, Hiragana, Katakana, Hangul) are treated as words of length 1 per grapheme cluster **run**: each ideograph run of length `k` is emphasised on its first `max(1, round_half_up(k * ratio))` clusters. Ports document which tokenizer they use; fixtures are split into `fixtures/common/*` (must match in every port) and `fixtures/segmenter/*` (only required when `Intl.Segmenter` is used).
* The `locale` option (BCP-47 string, default `undefined` → runtime default) is passed straight to the segmenter.
* Grapheme clusters are counted with `Intl.Segmenter(locale, { granularity: "grapheme" })` when available, otherwise by code points (`Array.from(word).length`). Combining marks therefore never get split from their base.

## 4. Public API (core)

```ts
export interface SmoothOptions {
  fixation?: 1 | 2 | 3 | 4 | 5;        // default 3
  saccade?: number;                     // default 1, integer >= 1
  minWordLength?: number;               // default 1
  emphasizeNumbers?: boolean;           // default false
  locale?: string;                      // BCP-47
  fixationLength?: (word: string, graphemes: number, opts: Required<SmoothOptions>) => number;
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

export const defaults: Required<SmoothOptions>;
```

Rules:

* `toHtml` escapes `<`, `>`, `&`, `"` in **text** it emits. Existing tags are passed through verbatim when `ignoreHtmlTags` is `true`.
* `saccade` counts **word** tokens only; the first word of the input always gets a fixation (index 0 mod saccade).
* Numbers count towards saccade indexing even when not emphasised.
* Output must be stable: `toHtml(x)` twice yields identical strings, and `tokenize` on already-emphasised HTML (with `ignoreHtmlTags: true`) does not double-wrap.

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
