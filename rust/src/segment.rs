//! Word boundaries and grapheme clusters (SPEC §3).
//!
//! Rust's standard library has no ICU break iterator, so the default
//! [`SpecSegmenter`] is the spec's regular-expression fallback, hand-written as
//! a scanner over the Unicode general categories in [`crate::unicode_data`].
//! It behaves exactly like the Python port: every space-separated script
//! matches the ICU-backed ports byte for byte, and a continuous run of
//! Chinese, Japanese or Thai text is one word.

use crate::unicode_data::{contains, is_letter, is_mark, is_number};

/// A raw segment of the input: a slice of the text plus whether it is a word.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Segment<'a> {
    /// The exact slice of the input.
    pub text: &'a str,
    /// `true` for a word, `false` for a separator (whitespace, punctuation,
    /// emoji, markup).
    pub is_word: bool,
}

/// Supplies word boundaries and grapheme clusters to the tokenizer (SPEC §3).
///
/// Applications that need dictionary-based word breaks for Chinese, Japanese
/// or Thai can implement this trait on top of a real break iterator (for
/// example the `icu_segmenter` crate, or a platform API) and pass it with
/// [`Options::segmenter`](crate::Options::segmenter). The fixation algorithm
/// itself never changes; only the boundary source does.
///
/// Contract: the returned segments and grapheme clusters must be consecutive
/// slices of the input, in order, concatenating back to it. Consecutive
/// separators may be returned as one segment or several; the tokenizer merges
/// them.
pub trait Segmenter: Send + Sync {
    /// Splits `text` into word and separator segments.
    fn segment_words<'a>(&self, text: &'a str, locale: Option<&str>) -> Vec<Segment<'a>>;

    /// Splits `text` into extended grapheme clusters (user-perceived characters).
    fn graphemes<'a>(&self, text: &'a str, locale: Option<&str>) -> Vec<&'a str>;
}

/// The spec's regular-expression segmenter (SPEC §3, fallback segmentation).
///
/// This is the default [`Segmenter`]. It needs no platform support and
/// produces the same output as the Python port and the TypeScript port's
/// non-ICU path. The `locale` argument is ignored.
///
/// ```
/// use smooth_reading::{Segment, Segmenter, SpecSegmenter};
///
/// let segments = SpecSegmenter.segment_words("iPhone手机", None);
/// assert_eq!(
///     segments,
///     [
///         Segment { text: "iPhone", is_word: true },
///         Segment { text: "手机", is_word: true },
///     ]
/// );
/// assert_eq!(SpecSegmenter.graphemes("naïve", None).len(), 5);
/// ```
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct SpecSegmenter;

/// Inclusive code-point ranges of the scripts written without spaces: the SPEC
/// §3 run table shared by every regex-fallback port. A character counts only
/// when it is also a letter, number or mark, so the Katakana middle dot
/// (U+30FB) stays punctuation.
#[rustfmt::skip]
const RUN_RANGES: &[(u32, u32)] = &[
    (0x0E00, 0x0E7F),   // Thai
    (0x0E80, 0x0EFF),   // Lao
    (0x1000, 0x109F),   // Myanmar
    (0x1100, 0x11FF),   // Hangul Jamo
    (0x1780, 0x17FF),   // Khmer
    (0x3005, 0x3007),   // ideographic iteration mark, ideographic zero
    (0x3041, 0x30FF),   // Hiragana, Katakana
    (0x3130, 0x318F),   // Hangul Compatibility Jamo
    (0x31F0, 0x31FF),   // Katakana Phonetic Extensions
    (0x3400, 0x4DBF),   // CJK Extension A
    (0x4E00, 0x9FFF),   // CJK Unified Ideographs
    (0xA960, 0xA97F),   // Hangul Jamo Extended-A
    (0xA9E0, 0xA9FF),   // Myanmar Extended-B
    (0xAA60, 0xAA7F),   // Myanmar Extended-A
    (0xAC00, 0xD7A3),   // Hangul Syllables
    (0xD7B0, 0xD7FF),   // Hangul Jamo Extended-B
    (0xF900, 0xFAFF),   // CJK Compatibility Ideographs
    (0xFF66, 0xFF9D),   // halfwidth Katakana
    (0xFFA0, 0xFFDC),   // halfwidth Hangul
    (0x20000, 0x2EBEF), // CJK Extensions B-F
    (0x2F800, 0x2FA1F), // CJK Compatibility Ideographs Supplement
    (0x30000, 0x323AF), // CJK Extensions G-H
];

/// Hangul jamo classes (`Hangul_Syllable_Type`), UAX #29 GB6–GB8.
const JAMO_L: &[(u32, u32)] = &[(0x1100, 0x115F), (0xA960, 0xA97C)];
const JAMO_V: &[(u32, u32)] = &[(0x1160, 0x11A7), (0xD7B0, 0xD7C6)];
const JAMO_T: &[(u32, u32)] = &[(0x11A8, 0x11FF), (0xD7CB, 0xD7FB)];
const SYLLABLE_FIRST: u32 = 0xAC00;
const SYLLABLE_LAST: u32 = 0xD7A3;

/// UAX #29 `GB9c` (Unicode 15.1): the `Indic_Conjunct_Break=Linker` viramas.
const INDIC_LINKERS: [char; 6] = [
    '\u{094D}', '\u{09CD}', '\u{0ACD}', '\u{0B4D}', '\u{0C4D}', '\u{0D4D}',
];

/// The `Indic_Conjunct_Break=Consonant` letters of the same six scripts.
#[rustfmt::skip]
const INDIC_CONSONANTS: &[(u32, u32)] = &[
    (0x0915, 0x0939), (0x0958, 0x095F), (0x0978, 0x097F),                   // Devanagari
    (0x0995, 0x09A8), (0x09AA, 0x09B0), (0x09B2, 0x09B2), (0x09B6, 0x09B9), // Bengali
    (0x09DC, 0x09DD), (0x09DF, 0x09DF), (0x09F0, 0x09F1),
    (0x0A95, 0x0AA8), (0x0AAA, 0x0AB0), (0x0AB2, 0x0AB3), (0x0AB5, 0x0AB9), // Gujarati
    (0x0AF9, 0x0AF9),
    (0x0B15, 0x0B28), (0x0B2A, 0x0B30), (0x0B32, 0x0B33), (0x0B35, 0x0B39), // Oriya
    (0x0B5C, 0x0B5D), (0x0B5F, 0x0B5F), (0x0B71, 0x0B71),
    (0x0C15, 0x0C28), (0x0C2A, 0x0C39), (0x0C58, 0x0C5A),                   // Telugu
    (0x0D15, 0x0D3A),                                                       // Malayalam
];

const ZWJ: char = '\u{200D}';

/// `\p{L}`, `\p{N}` or `\p{M}`: letters, numbers and marks.
fn is_word_char(c: char) -> bool {
    if c.is_ascii() {
        c.is_ascii_alphanumeric()
    } else {
        is_letter(c) || is_number(c) || is_mark(c)
    }
}

/// A word begins with a letter or number, never with a combining mark.
fn starts_word(c: char) -> bool {
    if c.is_ascii() {
        c.is_ascii_alphanumeric()
    } else {
        is_letter(c) || is_number(c)
    }
}

fn is_mark_char(c: char) -> bool {
    !c.is_ascii() && is_mark(c)
}

/// A no-space-script word character (Han, Kana, Hangul, Thai, …).
fn is_run_char(c: char) -> bool {
    !c.is_ascii() && contains(RUN_RANGES, u32::from(c)) && is_word_char(c)
}

/// Characters that join two word runs into one word (`don't`, `it’s`).
fn is_apostrophe(c: char) -> bool {
    c == '\'' || c == '\u{2019}'
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Jamo {
    L,
    V,
    T,
    Lv,
    Lvt,
}

/// The jamo class of `c`, if it is Hangul. LV/LVT precomposed syllables are
/// told apart arithmetically: every 28th code point from U+AC00 is LV.
fn jamo_class(c: char) -> Option<Jamo> {
    let code = u32::from(c);
    if (SYLLABLE_FIRST..=SYLLABLE_LAST).contains(&code) {
        return Some(if (code - SYLLABLE_FIRST) % 28 == 0 {
            Jamo::Lv
        } else {
            Jamo::Lvt
        });
    }
    if contains(JAMO_L, code) {
        Some(Jamo::L)
    } else if contains(JAMO_V, code) {
        Some(Jamo::V)
    } else if contains(JAMO_T, code) {
        Some(Jamo::T)
    } else {
        None
    }
}

/// GB6–GB8: whether two adjacent jamo classes stay in one syllable.
fn hangul_joins(previous: Option<Jamo>, following: Option<Jamo>) -> bool {
    match (previous, following) {
        (None, _) | (_, None) => false,
        (Some(Jamo::L), _) => true,
        (Some(Jamo::Lv | Jamo::V), Some(next)) => matches!(next, Jamo::V | Jamo::T),
        (Some(Jamo::Lvt | Jamo::T), Some(next)) => next == Jamo::T,
    }
}

fn is_indic_consonant(c: char) -> bool {
    contains(INDIC_CONSONANTS, u32::from(c))
}

fn is_indic_linker(c: char) -> bool {
    INDIC_LINKERS.contains(&c)
}

/// The characters of `text` with their byte offsets, plus a way to map a
/// character index back to a byte offset (`len` maps to the end of the text).
struct Chars<'a> {
    text: &'a str,
    chars: Vec<(usize, char)>,
}

impl<'a> Chars<'a> {
    fn new(text: &'a str) -> Self {
        Self {
            text,
            chars: text.char_indices().collect(),
        }
    }

    fn len(&self) -> usize {
        self.chars.len()
    }

    fn at(&self, index: usize) -> char {
        self.chars[index].1
    }

    fn slice(&self, start: usize, end: usize) -> &'a str {
        let byte = |index: usize| self.chars.get(index).map_or(self.text.len(), |c| c.0);
        &self.text[byte(start)..byte(end)]
    }
}

impl Segmenter for SpecSegmenter {
    /// SPEC §3 fallback tokenizer, exactly as the Python port scans it. Two
    /// kinds of word:
    ///
    /// * a continuous run of no-space-script characters (combining marks stay
    ///   attached), one word per run, split from adjacent text of other
    ///   scripts, so `iPhone手机` is `iPhone` + `手机` just as ICU breaks it;
    /// * otherwise the spec regex
    ///   `[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*`:
    ///   apostrophes join, hyphens split, and a word never starts with a
    ///   combining mark (a mark after a separator, such as the variation
    ///   selector of ❤️, belongs to that separator, as in UAX #29 WB4).
    fn segment_words<'a>(&self, text: &'a str, _locale: Option<&str>) -> Vec<Segment<'a>> {
        let chars = Chars::new(text);
        let len = chars.len();
        let mut out = Vec::new();
        let mut index = 0;
        while index < len {
            let start = index;
            let is_word = if !starts_word(chars.at(index)) {
                // Separator: a maximal run of non-word-start characters.
                while index < len && !starts_word(chars.at(index)) {
                    index += 1;
                }
                false
            } else if is_run_char(chars.at(index)) {
                // No-space-script run: one word per continuous run; marks that
                // follow a run character stay attached.
                while index < len && (is_run_char(chars.at(index)) || is_mark_char(chars.at(index)))
                {
                    index += 1;
                }
                true
            } else {
                // Ordinary word: word characters, optionally joined by
                // apostrophes, restricted to non-run characters. An apostrophe
                // joins only when the next character is a non-run word
                // character.
                loop {
                    while index < len
                        && is_word_char(chars.at(index))
                        && !is_run_char(chars.at(index))
                    {
                        index += 1;
                    }
                    let joins = index + 1 < len
                        && is_apostrophe(chars.at(index))
                        && is_word_char(chars.at(index + 1))
                        && !is_run_char(chars.at(index + 1));
                    if !joins {
                        break;
                    }
                    index += 1;
                }
                true
            };
            out.push(Segment {
                text: chars.slice(start, index),
                is_word,
            });
        }
        out
    }

    /// SPEC §3 fallback grapheme clustering, identical to the TypeScript and
    /// Python fallbacks: a code point plus any following combining marks
    /// (`\p{M}`, which includes variation selectors), a ZWJ joins the next
    /// code point, Hangul jamo sequences compose into syllables, Indic
    /// conjuncts of the Unicode 15.1 `GB9c` scripts link, and CR LF is one
    /// cluster. Regional indicator pairs are not composed, but they cannot
    /// occur inside a word token.
    fn graphemes<'a>(&self, text: &'a str, _locale: Option<&str>) -> Vec<&'a str> {
        let chars = Chars::new(text);
        let len = chars.len();
        let mut out = Vec::new();
        let mut start = 0;
        while start < len {
            let mut end = start + 1;
            if chars.at(start) == '\r' && end < len && chars.at(end) == '\n' {
                end += 1;
            }
            // GB9c state: the cluster ends in a consonant followed by a linker
            // (with only marks in between), so a following consonant joins.
            let saw_consonant = is_indic_consonant(chars.at(start));
            let mut linked = false;
            while end < len {
                let c = chars.at(end);
                if is_mark_char(c) {
                    if saw_consonant && is_indic_linker(c) {
                        linked = true;
                    }
                    end += 1;
                } else if c == ZWJ {
                    end = (end + 2).min(len); // the ZWJ and whatever it joins
                } else if hangul_joins(jamo_class(chars.at(end - 1)), jamo_class(c)) {
                    end += 1;
                } else if linked && is_indic_consonant(c) {
                    linked = false;
                    end += 1;
                } else {
                    break;
                }
            }
            out.push(chars.slice(start, end));
            start = end;
        }
        out
    }
}
