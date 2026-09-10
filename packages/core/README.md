# @smooth-reading/core

Guided fixation reading for the web: the first part of every word is emphasised,
so the eye gets an artificial fixation point and the brain completes the rest of
the word. It is the same idea as commercial fixation-reading products, done as a
zero-dependency, Apache-2.0 library with a written [specification](../../docs/SPEC.md)
that ports in other languages can follow byte-for-byte.

- **Zero runtime dependencies**, ESM + CJS, `sideEffects: false`.
- **Unicode-correct**: `Intl.Segmenter` for word breaks (Chinese, Japanese, Thai
  included) and grapheme clusters for counting, with a documented regex fallback.
- **Three entry points**: an HTML string (`toHtml`), tokens you render yourself
  (`tokenize`), and an in-place DOM pass with an undo (`applyToElement`).
- **Streaming**: `createTransformStream()` for LLM output and other chunked text.

## Install

```sh
npm install @smooth-reading/core
# pnpm add @smooth-reading/core   ·   yarn add @smooth-reading/core
```

## Usage

### 1. `toHtml` — a string in, HTML out

```ts
import { toHtml } from '@smooth-reading/core';

toHtml('Smooth reading works.');
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'

toHtml('Smooth reading works.', { fixation: 5, saccade: 2 });
// '<b>Smoot</b>h reading <b>work</b>s.'
```

Text is escaped (`&`, `<`, `>`, `"`); existing tags pass through verbatim, and
the text inside `skipTags` — plus anything already inside the emphasis tag — is
left exactly as it was:

```ts
toHtml('Try <code>toHtml(x)</code> now.');
// '<b>Tr</b>y <code>toHtml(x)</code> <b>no</b>w.'
```

### 2. `tokenize` — render it yourself

Framework adapters build real elements instead of HTML strings. `tokenize` gives
you everything you need:

```tsx
import { tokenize } from '@smooth-reading/core';

function SmoothText({ text }: { text: string }) {
  return (
    <>
      {tokenize(text).map((token, i) =>
        token.type === 'word' && token.fixation > 0 ? (
          <span key={i}>
            <b>{token.fixationText}</b>
            {token.restText}
          </span>
        ) : (
          <span key={i}>{token.text}</span>
        ),
      )}
    </>
  );
}
```

### 3. `applyToElement` — rewrite a live DOM subtree, then undo it

```ts
import { applyToElement } from '@smooth-reading/core';

const restore = applyToElement(document.querySelector('article')!, {
  fixation: 4,
  skipSelector: '.no-smooth, [data-verbatim]',
});

// later — the original text nodes come back, byte for byte
restore();
```

Each text node is processed on its own, so a word a browser has split across
inline elements (`smo<i>oth</i>`) is handled without moving any element.
Calling it twice is safe: nothing is ever wrapped twice, and no marker
attributes are left in your DOM.

### Streaming

```ts
import { createTransformStream } from '@smooth-reading/core';

await response.body!
  .pipeThrough(new TextDecoderStream())
  .pipeThrough(createTransformStream({ fixation: 3 }))
  .pipeTo(sink);
```

Only the tail after the last separator is buffered, so a word is never cut in
half and `saccade` numbering continues across chunks; `flush` emits the
remainder. The concatenated output is identical to `toHtml` of the whole input.

## Options

Shared by `tokenize`, `toHtml` and `applyToElement`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `1 \| 2 \| 3 \| 4 \| 5` | `3` | Fixation strength. Ratios `0.20 / 0.35 / 0.50 / 0.65 / 0.80` of the word, rounded half up, clamped to `1…n`. |
| `saccade` | `number` | `1` | Emphasise every *n*-th word. Every word token consumes an index, including numbers and words that are too short to be emphasised. |
| `minWordLength` | `number` | `1` | Words with fewer grapheme clusters get no fixation. |
| `emphasizeNumbers` | `boolean` | `false` | Emphasise words made entirely of digits. |
| `locale` | `string` | `undefined` | BCP-47 locale handed to `Intl.Segmenter`. |
| `fixationLength` | `(word, graphemes, opts) => number` | built-in | Replace the algorithm entirely. The return value is clamped to `0…graphemes`. |

Additional options for `toHtml`:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tag` | `string` | `"b"` | Element wrapped around the fixation prefix. |
| `className` | `string` | `undefined` | `class` attribute for that element. |
| `restTag` | `string` | `undefined` | Element wrapped around the rest of the word; omit for plain text. |
| `restClassName` | `string` | `undefined` | `class` attribute for the rest element. |
| `ignoreHtmlTags` | `boolean` | `true` | Pass `<...>` through verbatim instead of escaping it. |
| `skipTags` | `string[]` | `["code","pre","script","style","kbd","samp","textarea"]` | Elements whose text is never rewritten. |

Additional options for `applyToElement`: `tag`, `className`, `restTag`,
`restClassName`, `skipTags` (as above) and `skipSelector` — a CSS selector whose
matching elements and their whole subtrees are skipped.

Single-character words are a deliberate special case: they are emphasised only
from strength 3 upwards. Words made entirely of digits are never emphasised
unless `emphasizeNumbers` is on, whatever their length.

## CSS

The default output (`<b>`) needs no stylesheet. If you would rather style the
emphasis yourself, render semantic-neutral `<span>`s and import the optional
stylesheet:

```ts
import '@smooth-reading/core/styles.css';

toHtml(text, {
  tag: 'span',
  className: 'sr-fixation',
  restTag: 'span',
  restClassName: 'sr-rest',
});
```

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

Override them freely — many readers prefer `font-weight: 600` plus
`--sr-rest-opacity: 0.75` over full bold.

## `Intl.Segmenter`, CJK and Thai

When the runtime exposes `Intl.Segmenter` (every current browser, Node 16+,
Deno, Bun) it is used for both word breaks and grapheme counting. That is what
makes Chinese, Japanese, Khmer, Lao and Thai work at all: those scripts have no
spaces, so words come from ICU's dictionary rather than from whitespace.

```ts
toHtml('我喜欢阅读', { locale: 'zh' });   // '<b>我</b><b>喜</b>欢<b>阅</b>读'
toHtml('สวัสดีครับ', { locale: 'th' });   // '<b>สวั</b>สดี<b>ครั</b>บ'
```

Without `Intl.Segmenter` the library falls back to the regular expression the
spec prescribes, `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`, and counts code
points instead of grapheme clusters. The fallback agrees with `Intl.Segmenter`
for every fixture in `fixtures/common`, but a run of CJK text becomes a single
long "word". Check `usesIntlSegmenter` if you need to know which path is active,
and pass `locale` when you know the language — ICU's Japanese and Chinese
dictionaries differ.

## License

Apache-2.0
