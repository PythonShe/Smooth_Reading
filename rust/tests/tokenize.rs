//! Tokenizer behaviour from SPEC §1, §3 and §4, mirroring the Python port's
//! `test_tokenize.py`.

use std::sync::Arc;

use smooth_reading::{
    Options, Segment, Segmenter, SpecSegmenter, Token, TokenizeState, tokenize, tokenize_with_state,
};

fn texts(text: &str) -> Vec<(bool, &str)> {
    tokenize(text, &Options::new())
        .iter()
        .map(|token| (token.is_word(), token.text()))
        .collect()
}

fn words<'a>(text: &'a str, options: &Options) -> Vec<Token<'a>> {
    tokenize(text, options)
        .into_iter()
        .filter(Token::is_word)
        .collect()
}

fn word_texts(text: &str) -> Vec<&str> {
    words(text, &Options::new())
        .iter()
        .map(Token::text)
        .collect()
}

fn fixation(token: &Token<'_>) -> usize {
    match *token {
        Token::Word { fixation, .. } => fixation,
        Token::Separator { .. } => panic!("not a word: {token:?}"),
    }
}

fn fixation_text<'a>(token: &Token<'a>) -> &'a str {
    match *token {
        Token::Word { fixation_text, .. } => fixation_text,
        Token::Separator { .. } => panic!("not a word: {token:?}"),
    }
}

#[test]
fn round_trip_covers_the_input() {
    let text = "Hello, \"world\" -- don't stop; 42 中文 ok?\r\n";
    let joined: String = tokenize(text, &Options::new())
        .iter()
        .map(Token::text)
        .collect();
    assert_eq!(joined, text);
}

#[test]
fn empty_input() {
    assert!(tokenize("", &Options::new()).is_empty());
}

#[test]
fn basic_split() {
    assert_eq!(
        texts("Smooth reading works."),
        [
            (true, "Smooth"),
            (false, " "),
            (true, "reading"),
            (false, " "),
            (true, "works"),
            (false, ".")
        ]
    );
}

#[test]
fn hyphens_separate_words() {
    assert_eq!(
        texts("well-known"),
        [(true, "well"), (false, "-"), (true, "known")]
    );
}

#[test]
fn apostrophes_join_words() {
    assert_eq!(texts("don't"), [(true, "don't")]);
    assert_eq!(texts("don’t"), [(true, "don’t")]);
    assert_eq!(
        texts("rock 'n' roll"),
        [
            (true, "rock"),
            (false, " '"),
            (true, "n"),
            (false, "' "),
            (true, "roll")
        ]
    );
}

#[test]
fn trailing_and_doubled_apostrophes_are_separators() {
    assert_eq!(texts("dogs'"), [(true, "dogs"), (false, "'")]);
    assert_eq!(texts("a''b"), [(true, "a"), (false, "''"), (true, "b")]);
}

#[test]
fn underscore_and_decimal_point_are_separators() {
    assert_eq!(texts("a_b"), [(true, "a"), (false, "_"), (true, "b")]);
    assert_eq!(texts("3.14"), [(true, "3"), (false, "."), (true, "14")]);
}

#[test]
fn word_split_fields() {
    let token = words("reading", &Options::new())[0];
    assert_eq!(
        token,
        Token::Word {
            text: "reading",
            fixation: 4,
            fixation_text: "read",
            rest_text: "ing"
        }
    );
}

#[test]
fn unemphasised_word_has_empty_prefix() {
    assert_eq!(
        words("2024", &Options::new())[0],
        Token::Word {
            text: "2024",
            fixation: 0,
            fixation_text: "",
            rest_text: "2024"
        }
    );
}

#[test]
fn separator_tokens_have_no_fixation() {
    let tokens = tokenize("a b", &Options::new());
    assert_eq!(tokens[1], Token::Separator { text: " " });
    assert!(!tokens[1].is_word());
}

#[test]
fn saccade_counts_word_tokens_only() {
    let result = words("one, two; three four", &Options::new().saccade(2));
    let emphasised: Vec<bool> = result.iter().map(|t| fixation(t) > 0).collect();
    assert_eq!(emphasised, [true, false, true, false]);
}

#[test]
fn saccade_counts_numbers_even_though_they_are_not_emphasised() {
    let result = words("2024 smooth reading", &Options::new().saccade(2));
    let fixations: Vec<usize> = result.iter().map(fixation).collect();
    assert_eq!(fixations, [0, 0, 4]);
}

#[test]
fn first_word_always_gets_a_fixation() {
    assert_eq!(
        fixation(&words("smooth reading", &Options::new().saccade(9))[0]),
        3
    );
}

#[test]
fn each_cjk_run_is_one_word() {
    for text in ["中文测试", "ひらがな", "カタカナ", "한국어"] {
        assert_eq!(texts(text), [(true, text)]);
    }
}

#[test]
fn cjk_runs_split_from_latin_and_punctuation() {
    assert_eq!(texts("中文abc"), [(true, "中文"), (true, "abc")]);
    assert_eq!(
        texts("中文、日本語"),
        [(true, "中文"), (false, "、"), (true, "日本語")]
    );
    assert_eq!(
        texts("アイ・ウエ"),
        [(true, "アイ"), (false, "・"), (true, "ウエ")]
    );
}

#[test]
fn cjk_run_prefix_length() {
    assert_eq!(
        fixation_text(&words("中文测试", &Options::new())[0]),
        "中文"
    );
    assert_eq!(
        fixation_text(&words("中文测试", &Options::new().fixation(5))[0]),
        "中文测"
    );
}

#[test]
fn single_ideograph_follows_the_single_character_rule() {
    assert_eq!(fixation(&words("中", &Options::new().fixation(2))[0]), 0);
    assert_eq!(
        fixation_text(&words("中", &Options::new().fixation(3))[0]),
        "中"
    );
}

#[test]
fn thai_is_one_word_and_marks_stay_with_their_base() {
    let token = words("สวัสดี", &Options::new())[0];
    assert_eq!(token.text(), "สวัสดี");
    assert_eq!(fixation(&token), 2);
    assert_eq!(fixation_text(&token), "สวั");
}

#[test]
fn min_word_length_suppresses_short_words() {
    assert_eq!(
        fixation(&words("the", &Options::new().min_word_length(4))[0]),
        0
    );
    assert_eq!(
        fixation(&words("the", &Options::new().min_word_length(1))[0]),
        2
    );
}

#[test]
fn out_of_range_values_are_clamped() {
    assert_eq!(
        tokenize("hi there", &Options::new().saccade(0)),
        tokenize("hi there", &Options::new().saccade(1))
    );
    assert_eq!(
        tokenize("hi there", &Options::new().fixation(7)),
        tokenize("hi there", &Options::new().fixation(5))
    );
}

// --- no-space-script run rule (SPEC §3) ------------------------------------

#[test]
fn a_run_splits_from_letters_and_digits_of_other_scripts() {
    assert_eq!(word_texts("iPhone手机"), ["iPhone", "手机"]);
    assert_eq!(word_texts("abcก"), ["abc", "ก"]);
    assert_eq!(word_texts("日本語OKです"), ["日本語", "OK", "です"]);
    assert_eq!(word_texts("abc한글"), ["abc", "한글"]);
    assert_eq!(word_texts("2024年"), ["2024", "年"]);
    assert_eq!(word_texts("USB线"), ["USB", "线"]);
}

#[test]
fn one_word_per_continuous_run() {
    assert_eq!(word_texts("iPhone手机很好用"), ["iPhone", "手机很好用"]);
    assert_eq!(word_texts("ภาษาไทยง่าย"), ["ภาษาไทยง่าย"]); // Thai
    assert_eq!(word_texts("ພາສາລາວ"), ["ພາສາລາວ"]); // Lao
    assert_eq!(word_texts("မြန်မာ"), ["မြန်မာ"]); // Myanmar
    assert_eq!(word_texts("ខ្ញុំ"), ["ខ្ញុំ"]); // Khmer
}

#[test]
fn combining_marks_follow_the_run_character_they_attach_to() {
    assert_eq!(word_texts("我́x"), ["我́", "x"]);
    assert_eq!(word_texts("我́"), ["我́"]);
    // A mark that follows no word character belongs to the separator (WB4).
    assert_eq!(word_texts("abcั"), ["abc"]);
    assert_eq!(texts("❤️ love"), [(false, "❤️ "), (true, "love")]);
}

#[test]
fn an_apostrophe_never_joins_a_run_to_an_ordinary_word() {
    assert_eq!(word_texts("don't"), ["don't"]);
    assert_eq!(word_texts("it'手机"), ["it", "手机"]);
    assert_eq!(word_texts("手机'it"), ["手机", "it"]);
}

#[test]
fn only_run_table_characters_of_category_l_n_or_m_start_a_run() {
    // U+30FB Katakana middle dot is punctuation: a separator, not a run character.
    assert_eq!(word_texts("ア・イ"), ["ア", "イ"]);
    // U+3007 ideographic number zero is a letter, so it does form a run.
    assert_eq!(word_texts("\u{3007}\u{3007}"), ["\u{3007}\u{3007}"]);
}

#[test]
fn rtl_words_keep_their_logical_start() {
    let token = words("العربية", &Options::new())[0];
    assert!(token.text().starts_with(fixation_text(&token)));
    assert_eq!(fixation(&token), 4);
    let token = words("שלום", &Options::new())[0];
    assert_eq!(fixation_text(&token), "של");
}

// --- external state and custom segmenters ----------------------------------

#[test]
fn tokenize_with_state_continues_the_saccade_count() {
    let options = Options::new().saccade(3);
    let mut state = TokenizeState::default();
    let first = tokenize_with_state("one two", &options, &mut state);
    assert_eq!(state.word_index, 2);
    let second = tokenize_with_state("three four", &options, &mut state);
    assert_eq!(state.word_index, 4);
    assert_eq!(fixation(&first[0]), 2);
    assert_eq!(fixation(&first[2]), 0);
    assert_eq!(fixation(&second[0]), 0);
    assert_eq!(fixation(&second[2]), 2); // index 3, on the beat
}

/// Splits on ASCII spaces only, returning every space as its own separator.
struct SpaceSegmenter;

impl Segmenter for SpaceSegmenter {
    fn segment_words<'a>(&self, text: &'a str, _locale: Option<&str>) -> Vec<Segment<'a>> {
        let mut out = Vec::new();
        let mut start = 0;
        for (i, c) in text.char_indices() {
            if c == ' ' {
                if i > start {
                    out.push(Segment {
                        text: &text[start..i],
                        is_word: true,
                    });
                }
                out.push(Segment {
                    text: &text[i..=i],
                    is_word: false,
                });
                start = i + 1;
            }
        }
        if start < text.len() {
            out.push(Segment {
                text: &text[start..],
                is_word: true,
            });
        }
        out
    }

    fn graphemes<'a>(&self, text: &'a str, locale: Option<&str>) -> Vec<&'a str> {
        SpecSegmenter.graphemes(text, locale)
    }
}

#[test]
fn a_custom_segmenter_supplies_the_word_boundaries() {
    let options = Options::new()
        .segmenter(Arc::new(SpaceSegmenter))
        .locale("en");
    let tokens = tokenize("well-known  3.14", &options);
    assert_eq!(
        tokens,
        [
            Token::Word {
                text: "well-known",
                fixation: 5,
                fixation_text: "well-",
                rest_text: "known"
            },
            // Consecutive separators merge into one token.
            Token::Separator { text: "  " },
            Token::Word {
                text: "3.14",
                fixation: 2,
                fixation_text: "3.",
                rest_text: "14"
            },
        ]
    );
    assert_eq!(options.get_locale(), Some("en"));
    assert!(options.get_segmenter().is_some());
}

#[test]
fn the_default_segmenter_is_the_spec_scanner() {
    let with_spec = Options::new().segmenter(Arc::new(SpecSegmenter));
    let text = "iPhone手机 don't 3.14";
    assert_eq!(tokenize(text, &with_spec), tokenize(text, &Options::new()));
}
