//! Tokenization: words with their fixation split, and separators (SPEC §3, §4).

use crate::fixation::fixation_length;
use crate::options::Options;
use crate::segment::Segmenter;

/// A piece of the input: a word or a separator.
///
/// Tokens borrow from the input. Concatenating [`Token::text`] over the
/// slice returned by [`tokenize`] gives the input back unchanged, and for a
/// word `fixation_text` + `rest_text` == `text`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Token<'a> {
    /// A word, with its fixation split.
    Word {
        /// The exact slice of the input this word covers.
        text: &'a str,
        /// Number of emphasised leading grapheme clusters; `0` when the word
        /// gets no fixation (suppressed by a rule, or off the saccade beat).
        fixation: usize,
        /// The emphasised prefix (empty when `fixation` is `0`).
        fixation_text: &'a str,
        /// The rest of the word (the whole word when `fixation` is `0`).
        rest_text: &'a str,
    },
    /// Whitespace, punctuation, emoji or other non-word text between words.
    Separator {
        /// The exact slice of the input this separator covers.
        text: &'a str,
    },
}

impl<'a> Token<'a> {
    /// The exact slice of the input this token covers.
    #[must_use]
    pub const fn text(&self) -> &'a str {
        match self {
            Self::Word { text, .. } | Self::Separator { text } => text,
        }
    }

    /// `true` for [`Token::Word`], `false` for [`Token::Separator`].
    #[must_use]
    pub const fn is_word(&self) -> bool {
        matches!(self, Self::Word { .. })
    }

    /// A word that receives no emphasis: `fixation` `0`, all text in `rest_text`.
    const fn plain(text: &'a str) -> Self {
        Self::Word {
            text,
            fixation: 0,
            fixation_text: "",
            rest_text: text,
        }
    }
}

/// Saccade bookkeeping shared across several [`tokenize_with_state`] calls,
/// so [`to_html`](crate::to_html) keeps counting words across markup (SPEC §4).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TokenizeState {
    /// Index of the next word token; the first word of the input is `0`.
    pub word_index: usize,
}

/// Splits `text` into words and separators and computes each word's fixation
/// prefix (SPEC §3, §4).
///
/// ```
/// use smooth_reading::{Options, Token, tokenize};
///
/// let tokens = tokenize("Smooth reading", &Options::new());
/// assert_eq!(
///     tokens,
///     [
///         Token::Word { text: "Smooth", fixation: 3, fixation_text: "Smo", rest_text: "oth" },
///         Token::Separator { text: " " },
///         Token::Word { text: "reading", fixation: 4, fixation_text: "read", rest_text: "ing" },
///     ]
/// );
/// ```
#[must_use]
pub fn tokenize<'a>(text: &'a str, options: &Options) -> Vec<Token<'a>> {
    tokenize_with_state(text, options, &mut TokenizeState::default())
}

/// [`tokenize`] with an externally owned saccade counter.
///
/// Every word token advances `state.word_index`, so tokenizing one text in
/// several pieces keeps counting words across the pieces.
///
/// ```
/// use smooth_reading::{Options, Token, TokenizeState, tokenize_with_state};
///
/// let options = Options::new().saccade(2);
/// let mut state = TokenizeState::default();
/// let first = tokenize_with_state("one two", &options, &mut state);
/// let second = tokenize_with_state("three four", &options, &mut state);
/// assert_eq!(state.word_index, 4);
/// assert!(matches!(first[0], Token::Word { fixation: 2, .. })); // "one", index 0
/// assert!(matches!(first[2], Token::Word { fixation: 0, .. })); // "two", index 1, off the beat
/// assert!(matches!(second[0], Token::Word { fixation: 3, .. })); // "three", index 2, on the beat
/// assert!(matches!(second[2], Token::Word { fixation: 0, .. })); // "four", index 3, off the beat
/// ```
#[must_use]
pub fn tokenize_with_state<'a>(
    text: &'a str,
    options: &Options,
    state: &mut TokenizeState,
) -> Vec<Token<'a>> {
    let segmenter = options.segmenter_impl();
    let mut tokens: Vec<Token<'a>> = Vec::new();
    for segment in segmenter.segment_words(text, options.get_locale()) {
        if segment.text.is_empty() {
            continue;
        }
        if segment.is_word {
            tokens.push(word_token(segment.text, options, segmenter, state));
            continue;
        }
        // Consecutive separators merge into one token so every segmenter
        // produces the same token stream.
        if let Some(Token::Separator { text: last }) = tokens.last_mut() {
            if let Some(merged) = merge_adjacent(text, last, segment.text) {
                *last = merged;
                continue;
            }
        }
        tokens.push(Token::Separator { text: segment.text });
    }
    tokens
}

/// The slice of `text` covering `first` immediately followed by `second`, when
/// both are adjacent slices of `text` (which every well-behaved segmenter
/// returns); `None` otherwise.
fn merge_adjacent<'a>(text: &'a str, first: &str, second: &str) -> Option<&'a str> {
    let base = text.as_ptr().addr();
    let first_start = first.as_ptr().addr();
    let second_start = second.as_ptr().addr();
    if first_start < base
        || first_start + first.len() != second_start
        || second_start + second.len() > base + text.len()
    {
        return None;
    }
    let start = first_start - base;
    text.get(start..start + first.len() + second.len())
}

fn word_token<'a>(
    word: &'a str,
    options: &Options,
    segmenter: &dyn Segmenter,
    state: &mut TokenizeState,
) -> Token<'a> {
    // Every word token consumes a saccade index, including numbers and words
    // too short to be emphasised (SPEC §4).
    let on_saccade = state.word_index % options.get_saccade() == 0;
    state.word_index += 1;
    if !on_saccade {
        return Token::plain(word);
    }

    let graphemes = segmenter.graphemes(word, options.get_locale());
    let fixation = fixation_length(word, graphemes.len(), options).min(graphemes.len());
    if fixation == 0 {
        return Token::plain(word);
    }
    let split: usize = graphemes[..fixation].iter().map(|g| g.len()).sum();
    match (word.get(..split), word.get(split..)) {
        (Some(fixation_text), Some(rest_text)) => Token::Word {
            text: word,
            fixation,
            fixation_text,
            rest_text,
        },
        // Only reachable with a segmenter whose clusters are not slices of the
        // word; the word is then emitted unemphasised rather than mis-split.
        _ => Token::plain(word),
    }
}
