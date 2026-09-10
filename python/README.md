# smooth-reading

Guided fixation reading for Python: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this package is an independent, clean-room, zero-dependency Apache-2.0 implementation. The algorithm is formally defined in [`docs/SPEC.md`](../docs/SPEC.md), guaranteeing deterministic, byte-identical output with the TypeScript, Swift, and Kotlin ports across all shared fixtures.

- **Python 3.10+** supported.
- **Zero runtime dependencies**: Pure Python standard library (`unicodedata`, `html`, `argparse`).
- **Fully type-annotated**: Ships `py.typed` and passes `mypy --strict`.
- **Unicode-aware**: Accurately handles diacritics, combining marks, contractions, and multilingual scripts.
- **Built-in CLI**: Pipe files or stdin directly to HTML or Markdown.

---

## Installation

```bash
pip install smooth-reading
```

---

## Examples

### 1. Render HTML

```python
from smooth_reading import to_html

to_html("Smooth reading works.")
# '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
```

### 2. Configure strength, saccade intervals, and custom CSS classes

```python
from smooth_reading import to_html

# Emphasise every 2nd word at strength 5:
to_html("Smooth reading works.", fixation=5, saccade=2)
# '<b>Smoot</b>h reading <b>work</b>s.'

# Style with semantic spans and classes:
to_html(
    "Smooth reading",
    tag="span",
    class_name="sr-fixation",
    rest_tag="span",
    rest_class_name="sr-rest",
)
# '<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> <span class="sr-fixation">read</span><span class="sr-rest">ing</span>'
```

Pair with the core package stylesheet:

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

### 3. Work directly with tokens

```python
from smooth_reading import tokenize

for token in tokenize("Smooth reading", fixation=4):
    if token.type == "word":
        print(token.fixation_text, "|", token.rest_text)
# Smoo | th
# readi | ng
```

`tokenize` returns frozen `Token` dataclasses (`WordToken` and `SeparatorToken`), allowing custom renderers (Rich terminal UI, ReportLab PDF, Jinja templates, or AST builders) to render fixation text without parsing HTML.

### 4. Render Markdown

```python
from smooth_reading import to_markdown

to_markdown("Smooth reading works.")
# '**Smo**oth **read**ing **wor**ks.'
```

---

## HTML parsing and markup handling

By default (`ignore_html_tags=True`), `to_html` treats the input as HTML:
- Existing tags, comments, and character references (`&amp;`, `&#x27;`) pass through untouched and act as word boundaries.
- Text within tags listed in `skip_tags` (`code`, `pre`, `script`, `style`, `kbd`, `samp`, `textarea`) is never altered.
- Fixation `tag` and `rest_tag` elements are automatically protected against duplicate nesting.
- Emitted text characters (`&`, `<`, `>`, `"`) are safely escaped.

```python
from smooth_reading import to_html

to_html("<p>Smooth reading</p> <code>x = 1</code> <b>done</b> & gone")
# '<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code> <b>done</b> &amp; <b>go</b>ne'
```

Pass `ignore_html_tags=False` to treat the input as plain text and escape all HTML characters:

```python
to_html("Tom & Jerry <3", ignore_html_tags=False)
# '<b>To</b>m &amp; <b>Jer</b>ry &lt;3'
```

---

## Command-Line Interface (CLI)

The package includes a standalone CLI tool, `smooth-reading`:

```bash
# Convert a file to HTML
smooth-reading article.txt > article.html

# Read from standard input with custom strength and saccade
cat article.txt | smooth-reading --fixation 4 --saccade 2

# Generate Markdown output
smooth-reading --markdown notes.txt

# Use custom tags and classes
smooth-reading --tag span --class sr-fixation article.txt
```

### CLI flags

| Flag | Default | Description |
| --- | --- | --- |
| `file` | `stdin` | Input file path; omit or specify `-` to read standard input. |
| `--fixation {1..5}` | `3` | Fixation strength (ratio of word emphasised). |
| `--saccade N` | `1` | Saccade frequency: emphasise every *N*-th word. |
| `--min-word-length N` | `1` | Skip words with fewer than *N* grapheme clusters. |
| `--numbers` | off | Also emphasise words composed entirely of decimal digits. |
| `--tag NAME` | `b` | HTML tag wrapping each fixation prefix. |
| `--class NAME` | none | Optional `class` attribute on the fixation element. |
| `--no-ignore-html-tags` | off | Treat input as plain text and escape all markup. |
| `--markdown` | off | Emit Markdown emphasis (`**prefix**rest`) instead of HTML. |

---

## Configuration options

`tokenize`, `to_html`, and `to_markdown` accept algorithm options as keyword arguments, as an `Options` instance (`to_html(text, Options(fixation=4))`), or both (keywords override instance fields).

Out-of-range `fixation` (outside 1–5) and `saccade` (< 1) values are automatically clamped into valid ranges.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `1..5` | `3` | Ratio of word emphasised: `0.20, 0.35, 0.50, 0.65, 0.80`. Out-of-range values are clamped. |
| `saccade` | `int >= 1` | `1` | Saccade interval: emphasise every *N*-th word. Values `< 1` are clamped to `1`. |
| `min_word_length` | `int >= 0` | `1` | Words shorter than this get no fixation. |
| `emphasize_numbers` | `bool` | `False` | Whether to emphasise words consisting solely of digits. |
| `locale` | `str \| None` | `None` | BCP-47 tag, accepted for parity across ports (unused by regex scanner). |
| `fixation_length` | `Callable` | `None` | Custom callback `(word, graphemes, options) -> int` replacing the fixation calculation. |

`to_html` additionally accepts: `tag`, `class_name`, `rest_tag`, `rest_class_name`, `ignore_html_tags`, and `skip_tags`.
`to_markdown` additionally accepts: `marker` (default `"**"`).

---

## Algorithm

For a word of `n` grapheme clusters and strength `s`:

```
ratio     = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}[s]
prefixLen = clamp(floor(n * ratio + 0.5), 1, n)
```

Evaluation rules are applied in the following order:
1. Words made only of digits are skipped unless `emphasize_numbers=True`.
2. Words shorter than `min_word_length` are skipped.
3. A single-character word is emphasised only when `s >= 3`.
4. Otherwise, calculate `prefixLen` using integer-based half-up rounding (`floor((n * percent + 50) / 100)`).

---

## Tokenizer & Unicode handling

Python's built-in `re` module does not support Unicode `\p{...}` properties and `\w` erroneously includes underscores. The tokenizer is implemented as a fast scanner over `unicodedata.category`.

- **Word boundaries**: Words are maximal runs of letters, numbers, and marks, optionally connected by internal apostrophes (`don't` is one word; `well-known` splits at hyphens into two words).
- **Combining marks**: A word never begins with a combining mark; marks following separators (e.g. variation selectors in emoji sequences like `❤️`) remain attached to the separator.
- **Grapheme clusters**: Evaluated using a lightweight UAX #29 approximation without external dependencies:
  - Base characters plus following combining marks (`Mn`, `Mc`, `Me`) form a single cluster.
  - Zero-width joiners (ZWJ) connect to following characters.
  - Decomposed Hangul jamo sequences compose into complete syllables.
  - Indic conjuncts for Unicode 15.1 linker scripts (Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam — such as `क्ष`) remain unified as single clusters.
  - CR+LF pairs are treated as single clusters.

### Script behavior

All space-separated scripts (Latin, Greek, Cyrillic, Korean, Vietnamese, Indic scripts, Arabic, Hebrew, Persian, Urdu) render byte-identically to ICU-backed ports (`fixtures/common/scripts.json`).

For scripts without spaces (Chinese, Japanese, Thai, Lao, Khmer, Burmese), the package applies a predictable run rule: each unbroken run of ideographs or syllables is treated as a single word (`我喜欢阅读` → `<b>我喜欢</b>阅读`). This avoids third-party C/ICU dependencies while ensuring deterministic execution.

For detailed cross-platform comparisons, see [`docs/LANGUAGES.md`](../docs/LANGUAGES.md).

---

## Development

```bash
uv venv && uv pip install -e ".[dev]"
.venv/bin/python -m pytest
.venv/bin/python -m mypy --strict smooth_reading
.venv/bin/python -m ruff check && .venv/bin/python -m ruff format --check
```

---

## License

Apache-2.0. See [LICENSE](LICENSE).
