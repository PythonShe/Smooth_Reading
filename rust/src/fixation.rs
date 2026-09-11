//! The fixation-length algorithm (SPEC §2).

use crate::options::Options;
use crate::unicode_data::is_decimal_digit;

/// "Entirely digits" (SPEC §2 rule 1): decimal digits of any script, not `½`
/// or `Ⅻ`.
fn is_all_digits(word: &str) -> bool {
    !word.is_empty() && word.chars().all(is_decimal_digit)
}

/// How many leading grapheme clusters of `word` (`graphemes` long) to
/// emphasise, `0` meaning none (SPEC §2).
///
/// Rules are applied in order:
///
/// 1. a custom [`Options::fixation_length`] override replaces everything below
///    (its result is clamped to `0..=graphemes`);
/// 2. an empty word gets `0`;
/// 3. a digit-only word gets `0` unless `emphasize_numbers` is set;
/// 4. a word shorter than `min_word_length` gets `0`;
/// 5. a single-character word is emphasised only at strength `>= 3`;
/// 6. otherwise `clamp(round_half_up(n * ratio), 1, n)`, computed with the
///    integer formula `floor((n * percent + 50) / 100)` so every port agrees.
///
/// ```
/// use smooth_reading::{Options, fixation_length};
///
/// let options = Options::new();
/// assert_eq!(fixation_length("reading", 7, &options), 4);
/// assert_eq!(fixation_length("to", 2, &options), 1);
/// assert_eq!(fixation_length("2024", 4, &options), 0);
/// assert_eq!(fixation_length("2024", 4, &options.clone().emphasize_numbers(true)), 2);
/// assert_eq!(fixation_length("a", 1, &options.clone().fixation(2)), 0);
/// ```
#[must_use]
pub fn fixation_length(word: &str, graphemes: usize, options: &Options) -> usize {
    if let Some(custom) = options.get_fixation_length() {
        return custom(word, graphemes, options).min(graphemes);
    }
    if graphemes < 1 {
        return 0;
    }
    if is_all_digits(word) && !options.get_emphasize_numbers() {
        return 0;
    }
    if graphemes < options.get_min_word_length() {
        return 0;
    }
    if graphemes == 1 {
        return usize::from(options.get_fixation() >= 3);
    }
    // `n * percent` cannot overflow for any real word; should a caller pass an
    // absurd count, the ratio of an unbounded word is the word itself.
    let raw = graphemes
        .checked_mul(options.percent())
        .map_or(graphemes, |scaled| (scaled + 50) / 100);
    raw.clamp(1, graphemes)
}
