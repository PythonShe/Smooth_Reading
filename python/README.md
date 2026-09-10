# smooth-reading

Guided fixation reading for Python: the first few letters of every word are
emphasised so the eye gets an artificial fixation point and the brain completes
the rest of the word. The technique is similar to commercial fixation-reading
products; this package is an independent, clean-room Apache-2.0 implementation
and is not affiliated with any of them.

The algorithm is defined by [`docs/SPEC.md`](../docs/SPEC.md) in this repository
and is deterministic across every port, so the TypeScript, Python and future
implementations produce byte-identical HTML for the shared fixtures.

* Python 3.10+
* **Zero runtime dependencies**
* Fully type annotated, ships `py.typed`, passes `mypy --strict`
* Unicode-aware: combining marks, apostrophes, and Han / Kana / Hangul / Thai runs

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

to_html("Smooth reading", tag="span", class_name="sr-fixation",
        rest_tag="span", rest_class_name="sr-rest")
# '<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> ...'
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

`tokenize` returns frozen `Token` dataclasses, so any renderer (Rich, ReportLab,
a template engine, a DOM builder) can be driven from them without going through
HTML strings.

## Existing markup

`to_html` leaves markup alone by default: text inside `<...>` and character
entities such as `&amp;` are passed through verbatim, the content of
`code`, `pre`, `script`, `style`, `kbd`, `samp` and `textarea` is untouched
(case-insensitive and nesting-aware), and everything it emits itself has
`&`, `<`, `>` and `"` escaped.

```python
to_html("<p>Smooth reading</p> <code>x = 1</code>")
# '<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code>'
```

Pass `ignore_html_tags=False` to treat the input as plain text and escape any
markup in it instead.

## CLI

```bash
smooth-reading article.txt > article.html
cat article.txt | smooth-reading --fixation 4 --saccade 2
smooth-reading --markdown notes.txt      # **Smo**oth **read**ing
smooth-reading --tag span --class sr-fixation article.html
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `file` | stdin | Input file; omit or pass `-` to read standard input |
| `--fixation {1..5}` | `3` | Fixation strength: how much of each word is emphasised |
| `--saccade N` | `1` | Emphasise every Nth word |
| `--min-word-length N` | `1` | Skip words shorter than N characters |
| `--tag NAME` | `b` | HTML tag wrapping the fixation |
| `--class NAME` | none | `class` attribute for the fixation element |
| `--markdown` | off | Emit `**prefix**rest` instead of HTML |
| `--numbers` | off | Also emphasise words made only of digits |
| `--no-ignore-html-tags` | off | Treat the input as plain text and escape markup |

## Options

Every option is accepted by `tokenize`, `to_html` and `to_markdown` as a keyword
argument, as an `Options` instance (`options=Options(fixation=4)`), or as a
mapping. The `camelCase` spellings from the shared spec (`minWordLength`,
`emphasizeNumbers`) are accepted too, so JSON fixtures can be passed straight in.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `1..5` | `3` | Ratio of each word emphasised: 0.20, 0.35, 0.50, 0.65, 0.80 |
| `saccade` | `int >= 1` | `1` | Emphasise every Nth word; the first word always counts as index 0 |
| `min_word_length` | `int >= 0` | `1` | Words shorter than this get no fixation |
| `emphasize_numbers` | `bool` | `False` | Emphasise words made only of digits |
| `locale` | `str \| None` | `None` | BCP-47 tag, accepted for cross-port parity (unused by the regex tokenizer) |
| `fixation_length` | `(word, graphemes, options) -> int` | `None` | Replaces the algorithm entirely; the result is clamped to `0..graphemes` |

`to_html` additionally takes `tag`, `class_name`, `rest_tag`, `rest_class_name`,
`ignore_html_tags` and `skip_tags`.

## Algorithm

For a word of `n` grapheme clusters and strength `s`:

```
ratio     = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}[s]
prefixLen = clamp(floor(n * ratio + 0.5), 1, n)
```

with these filters applied first: words of one character need `s >= 3`, words
made only of digits are skipped unless `emphasize_numbers` is set, and words
shorter than `min_word_length` are skipped. Rounding is always half-up (never
banker's rounding) so every port agrees.

## Tokenizer and Unicode caveats

Python's `re` has no `\p{...}` property escapes and `\w` wrongly matches `_`, so
the spec tokenizer is implemented as a hand-written scanner over
`unicodedata.category`. Words are maximal runs of letters, numbers and marks,
optionally joined by `'` or `’`; hyphens separate (`well-known` →
`<b>we</b>ll-<b>kn</b>own`). A run of Han, Hiragana, Katakana, Hangul or Thai
characters is a single word, emphasised on its first `max(1, round(k * ratio))`
clusters.

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
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
