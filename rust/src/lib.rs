//! Guided fixation reading: the leading letters of every word are emphasised
//! so the eye lands on an artificial fixation point and the brain completes
//! the rest of the word.
//!
//! Similar to commercial fixation-reading products, this crate is an
//! independent, clean-room, zero-dependency implementation of the algorithm
//! defined in the Smooth Reading
//! [specification](https://github.com/PythonShe/Smooth_Reading/blob/main/docs/SPEC.md),
//! producing byte-identical output with the TypeScript, Swift, Kotlin, Python
//! and Dart ports across all shared fixtures.
//!
//! # Quick start
//!
//! ```
//! use smooth_reading::{HtmlOptions, Options, Token, to_html, to_markdown, tokenize};
//!
//! // HTML: the first half of each word is wrapped in <b>.
//! let html = to_html("Smooth reading works.", &Options::new(), &HtmlOptions::new());
//! assert_eq!(html, "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.");
//!
//! // Markdown.
//! assert_eq!(to_markdown("Smooth reading", &Options::new(), "**"), "**Smo**oth **read**ing");
//!
//! // Tokens, for rendering with your own text engine.
//! for token in tokenize("Smooth reading", &Options::new().fixation(4)) {
//!     match token {
//!         Token::Word { fixation_text, rest_text, .. } => println!("{fixation_text} | {rest_text}"),
//!         Token::Separator { text } => print!("{text}"),
//!     }
//! }
//! ```
//!
//! # Options
//!
//! [`Options`] holds the algorithm settings (`fixation` strength `1..=5`,
//! `saccade` interval, `min_word_length`, `emphasize_numbers`, `locale`, a
//! custom `fixation_length` override and a pluggable [`Segmenter`]);
//! [`HtmlOptions`] holds the markup settings for [`to_html`]. Both are
//! configured with chaining setters and clamp out-of-range values instead of
//! failing.
//!
//! # Unicode
//!
//! The default [`SpecSegmenter`] is the spec's regular-expression scanner over
//! a generated Unicode general-category table ([`unicode_data`], no runtime
//! dependencies), with grapheme clustering that keeps combining marks, Hangul
//! jamo, Indic conjuncts and emoji sequences whole. Right-to-left text is
//! never reordered: the fixation is always the logical start of the word. A
//! continuous run of Chinese, Japanese or Thai is one word; plug in a
//! dictionary-based [`Segmenter`] for finer breaks.

#![forbid(unsafe_code)]
#![warn(missing_docs)]

mod fixation;
mod html;
mod options;
mod segment;
mod tokenize;
pub mod unicode_data;

pub use fixation::fixation_length;
pub use html::{DEFAULT_SKIP_TAGS, HtmlOptions, escape_html, to_html, to_markdown};
pub use options::{FixationLengthFn, Options};
pub use segment::{Segment, Segmenter, SpecSegmenter};
pub use tokenize::{Token, TokenizeState, tokenize, tokenize_with_state};

/// The crate version, kept in step with every other Smooth Reading port.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
