# @smooth-reading/core

Guided fixation reading for modern JavaScript and TypeScript: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this package is an independent, clean-room, zero-dependency, Apache-2.0 library implemented strictly against the project [specification](../../docs/SPEC.md).

- **Zero runtime dependencies**: Pure TypeScript, ESM and CJS outputs, `sideEffects: false`, fully tree-shakeable.
- **Universal compatibility**: Runs in all modern browsers, Node.js 18+, Deno, Bun, and React Native (Hermes).
- **Unicode & script accurate**: Uses `Intl.Segmenter` for real dictionary word breaking (Chinese, Japanese, Thai, Lao, Khmer, Burmese) and grapheme cluster counting, with a spec-compliant regular expression fallback.
- **Four primary entry points**:
  - `toHtml`: Fast, safe HTML string transformer.
  - `tokenize`: Pure token array for building UI components without `innerHTML`.
  - `applyToElement`: Non-destructive DOM walker with a clean, idempotent `restore()` callback.
  - `createTransformStream`: Web standard streaming transform for LLM output and chunked text.

---

## Installation

```bash
npm install @smooth-reading/core
# pnpm add @smooth-reading/core  ·  yarn add @smooth-reading/core  ·  bun add @smooth-reading/core
```

---

## Usage

### 1. `toHtml` — String in, HTML out

```ts
import { toHtml } from '@smooth-reading/core';

toHtml('Smooth reading works.');
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'

toHtml('Smooth reading works.', { fixation: 5, saccade: 2 });
// '<b>Smoot</b>h reading <b>work</b>s.'
```

By default, the input is treated as HTML (`ignoreHtmlTags: true`):
- HTML tags and valid character references (`&amp;`, `&#x27;`) pass through untouched.
- Special HTML characters (`&`, `<`, `>`, `"`) in regular text are safely escaped.
- Text within elements listed in `skipTags` (such as `<code>` or `<pre>`), as well as text already inside emphasis tags, is left untouched.

```ts
toHtml('Try <code>toHtml(x)</code> now.');
// '<b>Tr</b>y <code>toHtml(x)</code> <b>no</b>w.'

toHtml('Tom & Jerry &amp; 5 < 6');
// '<b>To</b>m &amp; <b>Jer</b>ry &amp; 5 &lt; 6'
```

Pass `ignoreHtmlTags: false` to treat the entire input as plain text and escape all HTML characters.

---

### 2. `tokenize` — Build custom UI components

Framework components can render native elements instead of serializing to HTML strings. `tokenize` returns an array of structured tokens:

```tsx
import { tokenize } from '@smooth-reading/core';

export function SmoothText({ text }: { text: string }) {
  const tokens = tokenize(text);

  return (
    <>
      {tokens.map((token, index) =>
        token.type === 'word' && token.fixation > 0 ? (
          <span key={index}>
            <b>{token.fixationText}</b>
            {token.restText}
          </span>
        ) : (
          <span key={index}>{token.text}</span>
        ),
      )}
    </>
  );
}
```

- Concatenating `token.text` across all tokens reconstructs the original string byte-for-byte.
- For every word token: `token.fixationText + token.restText === token.text`.

For ready-to-use framework adapters, see [docs/recipes](../../docs/recipes/README.md) for React, Vue, Svelte, Angular, React Native, and Web Components.

---

### 3. `applyToElement` — In-place DOM enhancement with restoration

Use `applyToElement` to enhance existing server-rendered HTML or third-party markup in the browser:

```ts
import { applyToElement } from '@smooth-reading/core';

const article = document.querySelector('article')!;
const restore = applyToElement(article, {
  fixation: 4,
  skipSelector: '.no-smooth, [data-verbatim]',
});

// Later: restore original DOM text nodes byte-for-byte
restore();
```

- **Safe text node manipulation**: Processes each text node individually. Words split across inline elements (`smo<i>oth</i>`) are handled without restructuring the DOM. Text is inserted as text nodes, never via `innerHTML`.
- **Idempotent**: Tracks generated nodes and avoids double-wrapping.
- **Resilient cleanup**: `restore()` tolerates DOM mutations made while active. Removed wrappers are ignored, added content remains untouched, and re-calling `restore()` is a safe no-op.

---

### 4. Streaming with `createTransformStream`

Transform chunked text or streaming LLM completions in real time:

```ts
import { createTransformStream } from '@smooth-reading/core';

await response.body!
  .pipeThrough(new TextDecoderStream())
  .pipeThrough(createTransformStream({ fixation: 3 }))
  .pipeTo(writableDestination);
```

- Only the tail segment after the last safe boundary is buffered.
- Words, grapheme clusters, HTML tags, and character references are never split across chunks.
- `saccade` state is maintained seamlessly across chunks, and `flush` emits any remaining buffered text.
- Concatenated stream output is identical to calling `toHtml` on the full input.

---

## Configuration options

### Algorithm options

Shared across `tokenize`, `toHtml`, `applyToElement`, and `createTransformStream`:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `1 \| 2 \| 3 \| 4 \| 5` | `3` | Fixation strength. Ratios: `0.20 / 0.35 / 0.50 / 0.65 / 0.80`. Values outside `1…5` are automatically clamped. |
| `saccade` | `number` | `1` | Emphasises every *n*-th word. Every word token consumes an index (including numbers and short words). Values `< 1` are clamped to `1`. |
| `minWordLength` | `number` | `1` | Minimum grapheme clusters required for a word to receive fixation. |
| `emphasizeNumbers` | `boolean` | `false` | Whether to emphasise words composed entirely of decimal digits. |
| `locale` | `string` | `undefined` | BCP-47 language tag passed to `Intl.Segmenter`. Falls back to runtime default if unspecified or invalid. |
| `fixationLength` | `FixationLengthFn` | `undefined` | Custom function `(word, graphemes, options) => number` to override the fixation length algorithm. Output is clamped to `0…graphemes`. |

### HTML & Stream options

Additional options accepted by `toHtml` and `createTransformStream`:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `tag` | `string` | `"b"` | Tag name wrapping the fixation prefix. |
| `className` | `string` | `undefined` | Optional `class` attribute for the fixation element. |
| `restTag` | `string` | `undefined` | Optional tag name wrapping the remainder of the word. Omit to leave as plain text. |
| `restClassName` | `string` | `undefined` | Optional `class` attribute for the rest element. |
| `ignoreHtmlTags` | `boolean` | `true` | When `true`, preserves existing HTML tags and entities. When `false`, treats input as plain text and escapes all HTML characters. |
| `skipTags` | `string[]` | `defaultSkipTags` | Tag names whose contents are never modified. Defaults to `["code","pre","script","style","kbd","samp","textarea"]`. |

### DOM options

`applyToElement` accepts all options above plus:
- `skipSelector`: CSS selector matching elements (and their subtrees) to skip entirely.

---

## Exports

| Export | Description |
| --- | --- |
| `tokenize(text, options?)` | Returns structured tokens (`words` and `separators`) with computed fixation splits. |
| `toHtml(text, options?)` | Transforms input string to formatted HTML. |
| `applyToElement(root, options?)` | In-place DOM transformation; returns cleanup `restore()` function. |
| `createTransformStream(options?)` | Web standard `TransformStream<string, string>` with `toHtml` semantics. |
| `fixationLength(word, graphemes, options)` | Standalone fixation calculation helper for custom overrides. |
| `defaults` | Frozen resolved default options (`ResolvedSmoothOptions`). |
| `defaultSkipTags` | Default list of skipped HTML tag names. |
| `usesIntlSegmenter()` | Returns `true` if the current runtime environment supports `Intl.Segmenter`. |
| `styles.css` | Optional stylesheet for styling semantic `<span>` tags. |

---

## Styling with CSS

The default output (`<b>`) works out of the box without extra stylesheets. If you prefer custom styling (e.g. semibold, custom color, or opacity), render semantic `<span>` tags and import `styles.css`:

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
.sr-fixation {
  font-weight: 700;
  color: var(--sr-fixation-color, inherit);
}

.sr-rest {
  opacity: var(--sr-rest-opacity, 1);
}
```

Many readers prefer a softer emphasis, such as `font-weight: 600` combined with `--sr-rest-opacity: 0.8`.

---

## `Intl.Segmenter` & Non-Latin scripts

When supported by the JavaScript runtime (modern browsers, Node.js 16+, Deno, Bun, and recent Hermes), `Intl.Segmenter` provides ICU dictionary-based word breaking and extended grapheme cluster counting. This enables accurate word boundary detection for scripts written without spaces, such as Chinese, Japanese, and Thai:

```ts
toHtml('我喜欢阅读', { locale: 'zh' }); // '<b>我</b><b>喜</b>欢<b>阅</b>读'
toHtml('สวัสดีครับ', { locale: 'th' }); // '<b>สวั</b>สดี<b>ครั</b>บ'
```

### Regular expression fallback

In runtimes lacking `Intl.Segmenter`, the library falls back to the specification's regular expression scanner:
`[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*`

Grapheme clusters are approximated as a base character plus following combining marks (including ZWJ sequences and CR LF). The fallback produces identical output to `Intl.Segmenter` for all space-separated scripts in `fixtures/common/`. For unbroken CJK or Thai text, it treats each unbroken run as a single word.

Runtime capability is detected dynamically on each call, so polyfills loaded after initialization are picked up automatically. Use `usesIntlSegmenter()` to inspect active segmentation mode.

---

## License

Apache-2.0. See [LICENSE](../../LICENSE).
