# smooth-reading

Guided fixation reading for Python: the first few letters of every word are
emphasised so the eye gets an artificial fixation point and the brain completes
the rest of the word. The technique is similar to commercial fixation-reading
products; this package is an independent Apache-2.0 implementation and is not
affiliated with any of them.

The algorithm is defined by [`docs/SPEC.md`](../docs/SPEC.md) in this repository
and is deterministic across every port, so the TypeScript, Swift, Kotlin and
Python implementations produce byte-identical HTML for the shared fixtures.

* Python 3.10+
* **Zero runtime dependencies**
* Fully type annotated, ships `py.typed`, passes `mypy --strict`
* Unicode-aware: combining marks, apostrophes, and Han / Kana / Hangul runs

## Install

```bash
pip install smooth-reading
```

## Examples

### 1. Render HTML

```python
from smooth_reading import to_html

to_html("Smooth reading works.")
# '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
```

### 2. Tune the strength, skip words, style with a class

```python
from smooth_reading import to_html

to_html("Smooth reading works.", fixation=5, saccade=2)
# '<b>Smoot</b>h reading <b>work</b>s.'

to_html(
    "Smooth reading",
    tag="span",
    class_name="sr-fixation",
    rest_tag="span",
    rest_class_name="sr-rest",
)
# '<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> <span class="sr-fixation">read</span><span class="sr-rest">ing</span>'
```

Pair it with the stylesheet shipped by the core package:

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

### 3. Work with tokens directly

```python
from smooth_reading import tokenize

for token in tokenize("Smooth reading", fixation=4):
    if token.type == "word":
        print(token.fixation_text, "|", token.rest_text)
# Smoo | th
# readi | ng
```

`tokenize` returns frozen `Token` dataclasses (`type`, `text`, and for words
`fixation`, `fixation_text`, `rest_text`), so any renderer (Rich, ReportLab, a
template engine, a DOM builder) can be driven from them without going through
HTML strings.

### 4. Markdown

```python
from smooth_reading import to_markdown

to_markdown("Smooth reading works.")
# '**Smo**oth **read**ing **wor**ks.'
```

## Existing markup

`to_html` leaves markup alone by default: tags and character references such
as `&amp;` are passed through verbatim (a reference acts as a word boundary),
the content of `code`, `pre`, `script`, `style`, `kbd`, `samp` and `textarea`
is untouched (case-insensitive and nesting-aware), and everything emitted as
text has `&`, `<`, `>` and `"` escaped. A `<` that is not followed by a letter,
`/`, `!` or `?` is ordinary text. The emphasis `tag` and `rest_tag` are treated
as skip tags too, so already-emphasised markup is never wrapped a second time.

```python
from smooth_reading import to_html

to_html("<p>Smooth reading</p> <code>x = 1</code> <b>done</b> & gone")
# '<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code> <b>done</b> &amp; <b>go</b>ne'
```

Pass `ignore_html_tags=False` to treat the input as plain text: every `<`, `>`
and `&` is escaped, including the `&` of an existing character reference.

```python
from smooth_reading import to_html

to_html("Tom & Jerry <3", ignore_html_tags=False)
# '<b>To</b>m &amp; <b>Jer</b>ry &lt;3'
```

## CLI

```bash
smooth-reading article.txt > article.html
cat article.txt | smooth-reading --fixation 4 --saccade 2
smooth-reading --markdown notes.txt      # **Smo**oth **read**ing
smooth-reading --tag span --class sr-fixation article.txt
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `file` | stdin | Input file; omit or pass `-` to read standard input |
| `--fixation {1..5}` | `3` | Fixation strength: how much of each word is emphasised |
| `--saccade N` | `1` | Emphasise every Nth word |
| `--min-word-length N` | `1` | Skip words shorter than N characters |
| `--numbers` | off | Also emphasise words made only of digits |
| `--tag NAME` | `b` | HTML tag wrapping the fixation |
| `--class NAME` | none | `class` attribute for the fixation element |
| `--no-ignore-html-tags` | off | Treat the input as plain text and escape markup |
| `--markdown` | off | Emit `**prefix**rest` instead of HTML |

## Options

`tokenize`, `to_html` and `to_markdown` take the algorithm options as keyword
arguments, as an `Options` instance (`to_html(text, Options(fixation=4))`), or
both (keywords override the instance). Invalid values raise `ValueError`;
unknown names raise `TypeError`. `DEFAULTS` is the spec default `Options()`.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `1..5` | `3` | Ratio of each word emphasised: 0.20, 0.35, 0.50, 0.65, 0.80 |
| `saccade` | `int >= 1` | `1` | Emphasise every Nth word; the first word always counts as index 0 |
| `min_word_length` | `int >= 0` | `1` | Words shorter than this get no fixation |
| `emphasize_numbers` | `bool` | `False` | Emphasise words made only of digits |
| `locale` | `str \| None` | `None` | BCP-47 tag, accepted for cross-port parity (unused by the regex tokenizer) |
| `fixation_length` | `(word, graphemes, options) -> int` | `None` | Replaces the algorithm entirely; the result is clamped to `0..graphemes` |

`to_html` additionally takes the keyword-only `tag`, `class_name`, `rest_tag`,
`rest_class_name`, `ignore_html_tags` and `skip_tags` (default `SKIP_TAGS`);
`to_markdown` takes `marker` (default `"**"`).

`fixation_length(word, graphemes, options=DEFAULTS)` exposes the bare
algorithm for a single word.

## Algorithm

For a word of `n` grapheme clusters and strength `s`:

```
ratio     = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}[s]
prefixLen = clamp(floor(n * ratio + 0.5), 1, n)
```

with these rules applied first, in this order: words made only of digits are
skipped unless `emphasize_numbers` is set, words shorter than `min_word_length`
are skipped, and a one-character word is emphasised only when `s >= 3`.
Rounding is always half-up (never banker's rounding) so every port agrees.

## Tokenizer and Unicode caveats

Python's `re` has no `\p{...}` property escapes and `\w` wrongly matches `_`, so
the spec tokenizer is implemented as a hand-written scanner over
`unicodedata.category`. Words are maximal runs of letters, numbers and marks,
optionally joined by `'` or `’`; hyphens separate (`well-known` →
`<b>we</b>ll-<b>kno</b>wn`). A run of Han, Hiragana, Katakana or Hangul
characters is a single word and follows the same fixation rules as any other
word. There is no dictionary-based word
breaking, so `fixtures/segmenter/*` (which need ICU) do not apply to this port.

Grapheme clusters are approximated rather than fully segmented per UAX #29: a
base character plus any following combining marks (`Mn`/`Mc`/`Me`, which covers
variation selectors) is one cluster, ZWJ joins the following character, and
CR+LF is one cluster. Regional-indicator pairs (flag emoji) still count as two
and Hangul jamo sequences are not composed — none of which occur inside word
tokens. Full UAX #29 support would need the third-party `regex` module, which
this package deliberately avoids.

## Development

```bash
uv venv && uv pip install -e ".[dev]"
.venv/bin/python -m pytest
.venv/bin/python -m mypy --strict smooth_reading
.venv/bin/python -m ruff check && .venv/bin/python -m ruff format --check
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
