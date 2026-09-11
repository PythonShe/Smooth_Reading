# smooth-reading

Guided fixation reading for Rust: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this crate is an independent, clean-room, zero-dependency Apache-2.0 implementation. The algorithm is formally defined in [`docs/SPEC.md`](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/SPEC.md), guaranteeing deterministic, byte-identical output with the TypeScript, Swift, Kotlin, Python and Dart ports across all shared fixtures.

- **Rust 1.85+**, edition 2024, `#![forbid(unsafe_code)]`.
- **Zero runtime dependencies**: only `std`; the Unicode general-category table the tokenizer needs is generated into the crate.
- **Borrowed tokens**: `tokenize()` returns `Token<'a>` slices of your input, ready for any text engine, with no allocation per word.
- **Unicode-aware**: diacritics, combining marks, Hangul jamo, Indic conjuncts, contractions, right-to-left scripts and emoji sequences are never split.
- **Pluggable segmenter**: plug in an ICU word breaker (for example the `icu_segmenter` crate) for dictionary-based Chinese, Japanese and Thai word breaks without changing the algorithm.
- **CLI included**: `smooth-reading` reads a file or stdin and writes HTML or Markdown.

---

## Installation

```bash
cargo add smooth-reading
# or, for the command line tool
cargo install smooth-reading
```

---

## Examples

### 1. Render HTML

```rust
use smooth_reading::{HtmlOptions, Options, to_html};

let html = to_html("Smooth reading works.", &Options::new(), &HtmlOptions::new());
assert_eq!(html, "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.");
```

### 2. Configure strength, saccade interval and CSS classes

```rust
use smooth_reading::{HtmlOptions, Options, to_html};

// Emphasise every 2nd word at strength 5:
let options = Options::new().fixation(5).saccade(2);
assert_eq!(
    to_html("Smooth reading works.", &options, &HtmlOptions::new()),
    "<b>Smoot</b>h reading <b>work</b>s."
);

// Style with semantic spans and classes:
let spans = HtmlOptions::new()
    .tag("span")
    .class_name("sr-fixation")
    .rest_tag("span")
    .rest_class_name("sr-rest");
assert_eq!(
    to_html("Smooth reading", &Options::new(), &spans),
    r#"<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> <span class="sr-fixation">read</span><span class="sr-rest">ing</span>"#
);
```

Pair with the core package stylesheet:

```css
.sr-fixation { font-weight: 700; }
.sr-rest     { opacity: var(--sr-rest-opacity, 1); }
```

### 3. Work directly with tokens

```rust
use smooth_reading::{Options, Token, tokenize};

for token in tokenize("Smooth reading", &Options::new().fixation(4)) {
    match token {
        Token::Word { fixation_text, rest_text, fixation, .. } if fixation > 0 => {
            println!("{fixation_text} | {rest_text}");
        }
        Token::Word { text, .. } | Token::Separator { text } => print!("{text}"),
    }
}
// Smoo | th
// readi | ng
```

`Token<'a>` is an enum with two variants, `Word` (`text`, `fixation`, `fixation_text`, `rest_text`, where `fixation_text` + `rest_text` == `text`) and `Separator` (`text`). Every field is a slice of the input; concatenating `token.text()` over the vector gives the input back unchanged. A `match` over the enum is exhaustive, which is what a GUI text builder wants.

### 4. Render Markdown

```rust
use smooth_reading::{Options, to_markdown};

assert_eq!(
    to_markdown("Smooth reading works.", &Options::new(), "**"),
    "**Smo**oth **read**ing **wor**ks."
);
```

### 5. Command line

```bash
echo "Smooth reading works." | smooth-reading
# <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.

smooth-reading --fixation 4 --saccade 2 --tag span --class sr-fixation article.html
smooth-reading --markdown notes.md
smooth-reading --help
```

Options: `[FILE|-]`, `--fixation N` (1–5), `--saccade N`, `--min-word-length N`, `--numbers`, `--tag TAG`, `--class CLASS`, `--no-ignore-html-tags`, `--markdown`, `--version`. The output is written without a trailing newline; the exit code is `2` for a usage error and `1` for an I/O error, exactly like the Python port's CLI.

---

## HTML parsing and markup handling

By default (`ignore_html_tags(true)`) `to_html` treats the input as HTML:

- Existing tags, comments and character references (`&amp;`, `&#x27;`) pass through untouched and act as word boundaries.
- Text inside `skip_tags` elements (`code`, `pre`, `script`, `style`, `kbd`, `samp`, `textarea`) is never altered.
- The fixation `tag` and `rest_tag` are added to the skip list automatically, so already-emphasised markup is never wrapped twice.
- Emitted text has `& < > "` escaped.

```rust
use smooth_reading::{HtmlOptions, Options, to_html};

assert_eq!(
    to_html("<p>Smooth reading</p> <code>x = 1</code> <b>done</b> & gone", &Options::new(), &HtmlOptions::new()),
    "<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code> <b>done</b> &amp; <b>go</b>ne"
);
```

Pass `ignore_html_tags(false)` to treat the input as plain text and escape every HTML character:

```rust
use smooth_reading::{HtmlOptions, Options, to_html};

assert_eq!(
    to_html("Tom & Jerry <3", &Options::new(), &HtmlOptions::new().ignore_html_tags(false)),
    "<b>To</b>m &amp; <b>Jer</b>ry &lt;3"
);
```

---

## Configuration options

`Options` is built with chaining setters; out-of-range `fixation` (outside 1–5) and `saccade` (< 1) are clamped into range rather than rejected. Because the setters own the plain names, the getters carry a `get_` prefix (`get_fixation()`, `get_saccade()`, …), as on `std::process::Command`.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `u8` 1..=5 | `3` | Ratio of the word emphasised: `0.20, 0.35, 0.50, 0.65, 0.80`. |
| `saccade` | `usize >= 1` | `1` | Emphasise every *N*-th word. |
| `min_word_length` | `usize` | `1` | Words shorter than this get no fixation. |
| `emphasize_numbers` | `bool` | `false` | Whether words made only of decimal digits are emphasised. |
| `locale` | `impl Into<String>` | none | BCP-47 tag, passed to the `segmenter`; the built-in one ignores it. |
| `fixation_length` | `Fn(&str, usize, &Options) -> usize` | none | Custom `(word, graphemes, options)` rule replacing the fixation calculation; the result is clamped to `0..=graphemes`. |
| `segmenter` | `Arc<dyn Segmenter>` | `SpecSegmenter` | Source of word boundaries and grapheme clusters (see below). |

`HtmlOptions` additionally has `tag`, `class_name`, `rest_tag`, `rest_class_name`, `ignore_html_tags` and `skip_tags`; `to_markdown` takes a `marker` (`"**"` for bold).

---

## Algorithm

For a word of `n` grapheme clusters and strength `s`:

```
ratio     = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}[s]
prefixLen = clamp(floor(n * ratio + 0.5), 1, n)
```

Rules are applied in order:

1. Words made only of digits are skipped unless `emphasize_numbers` is `true`.
2. Words shorter than `min_word_length` are skipped.
3. A single-character word is emphasised only when `s >= 3`.
4. Otherwise `prefixLen` is computed with integer half-up rounding, `floor((n * percent + 50) / 100)`.

`fixation_length(word, graphemes, options)` is exported so you can compute the split for a word you have already segmented. Saccade counting is by word token only (numbers and short words still count), continues across markup in `to_html`, and never counts text inside skipped elements.

---

## Tokenizer, Unicode and the `Segmenter` trait

Rust's standard library has no ICU break iterator and no Unicode general-category lookup, so the default `SpecSegmenter` is the spec's regular-expression scanner, hand-written over a generated table of the `L`, `N`, `Nd` and `M` categories (`src/unicode_data.rs`, from `UnicodeData.txt`; regenerate with `python3 tools/gen_unicode_data.py`). It produces exactly the same output as the Python port:

- **Word boundaries**: maximal runs of letters, numbers and marks, optionally joined by internal apostrophes (`don't` is one word; `well-known` splits at the hyphen). A word never starts with a combining mark; a mark following a separator (the variation selector in `❤️`) stays with the separator.
- **Grapheme clusters**: a UAX #29 approximation with no dependencies. Base characters plus combining marks form one cluster, a ZWJ joins the next character, decomposed Hangul jamo compose into syllables, Indic conjuncts of the Unicode 15.1 linker scripts (Devanagari, Bengali, Gujarati, Oriya, Telugu, Malayalam, e.g. `क्ष`) stay whole, and CR LF is one cluster.
- **Scripts without spaces**: each unbroken run of Han, Kana, Hangul, Thai, Lao, Myanmar or Khmer is one word (`我喜欢阅读` → `<b>我喜欢</b>阅读`), and a run is split from adjacent Latin text (`iPhone手机` → `iPhone` + `手机`), matching how ICU breaks script boundaries.
- **Bidirectional text**: the emitted markup never adds `dir` attributes, `<bdi>` wrappers or bidi control characters; the fixation is always the logical start of the word, so Arabic, Hebrew, Persian and Urdu keep their order.

All space-separated scripts (Latin, Greek, Cyrillic, Korean, Vietnamese, Indic scripts, Arabic, Hebrew, Persian, Urdu) render byte-identically to the ICU-backed ports; the crate passes every case in `fixtures/common/`, including `scripts.json`.

### Dictionary word breaks for Chinese, Japanese and Thai

Implement `Segmenter` on top of a real break iterator and pass it in `Options`. The algorithm, saccade counting and HTML rendering are unchanged; only the boundary source differs. A sketch over the `icu_segmenter` crate (check its documentation for the exact API of the version you use):

```rust
use std::sync::Arc;

use icu_segmenter::{GraphemeClusterSegmenter, WordSegmenter};
use smooth_reading::{Options, Segment, Segmenter, tokenize};

struct IcuSegmenter {
    words: WordSegmenter,
    graphemes: GraphemeClusterSegmenter,
}

impl Segmenter for IcuSegmenter {
    fn segment_words<'a>(&self, text: &'a str, _locale: Option<&str>) -> Vec<Segment<'a>> {
        let mut out = Vec::new();
        let mut start = 0;
        let mut breaks = self.words.segment_str(text);
        while let Some(end) = breaks.next() {
            if end > start {
                out.push(Segment { text: &text[start..end], is_word: breaks.is_word_like() });
                start = end;
            }
        }
        out
    }

    fn graphemes<'a>(&self, text: &'a str, _locale: Option<&str>) -> Vec<&'a str> {
        let mut out = Vec::new();
        let mut start = 0;
        for end in self.graphemes.segment_str(text) {
            if end > start {
                out.push(&text[start..end]);
                start = end;
            }
        }
        out
    }
}

let segmenter = Arc::new(IcuSegmenter {
    words: WordSegmenter::new_auto(Default::default()),
    graphemes: GraphemeClusterSegmenter::new(),
});
let options = Options::new().locale("zh").segmenter(segmenter);
let tokens = tokenize("iPhone手机很好用", &options); // iPhone, 手机, 很好, 用
```

The contract: segments and clusters must be consecutive slices of the input that concatenate back to it. Consecutive separators may come back as one segment or several; the tokenizer merges them.

For the detailed cross-platform comparison see [`docs/LANGUAGES.md`](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/LANGUAGES.md).

---

## Development

```bash
cd rust
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo doc --no-deps
```

The tests run the shared `fixtures/common/*.json` suite from the repository root and the lossless/bidi invariants over `fixtures/segmenter/*.json` as well (those two test files need the monorepo checkout and are not part of the published crate).

---

## License

Apache-2.0. See [LICENSE](LICENSE).
