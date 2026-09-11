//! Multilingual and bidi guarantees over every fixture input, including the
//! `segmenter` suite this regex port is not expected to *match*: tokens are
//! lossless, the markup adds nothing but emphasis tags, and no
//! direction-changing attribute or bidi control character is ever introduced.
//! Mirrors `dart/test/languages_test.dart` and `python/tests/test_languages.py`.

mod support;

use smooth_reading::unicode_data::is_mark;
use smooth_reading::{Options, Token, escape_html, tokenize};
use support::{Fixture, load_fixtures};

fn cases() -> Vec<Fixture> {
    let mut cases = load_fixtures("common");
    cases.extend(load_fixtures("segmenter"));
    cases
}

/// LRM, RLM, ALM, the explicit embeddings/overrides and the isolates.
fn is_bidi_control(c: char) -> bool {
    matches!(c, '\u{200E}' | '\u{200F}' | '\u{061C}' | '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}')
}

/// The length of an emphasis tag (`</?(?:tags)(?:\s[^>]*)?>`) at the start of
/// `s`, if there is one.
fn emphasis_tag_len(s: &str, tags: &[String]) -> Option<usize> {
    let body = s.strip_prefix('<')?;
    let body = body.strip_prefix('/').unwrap_or(body);
    for tag in tags {
        let Some(after) = body.strip_prefix(tag.as_str()) else {
            continue;
        };
        if after.starts_with('>') {
            return Some(s.len() - after.len() + 1);
        }
        if after.starts_with(char::is_whitespace) {
            if let Some(end) = after.find('>') {
                return Some(s.len() - after.len() + end + 1);
            }
        }
    }
    None
}

fn strip_emphasis(markup: &str, tags: &[String]) -> String {
    let mut out = String::new();
    let mut rest = markup;
    while let Some(i) = rest.find('<') {
        out.push_str(&rest[..i]);
        let candidate = &rest[i..];
        if let Some(len) = emphasis_tag_len(candidate, tags) {
            rest = &candidate[len..];
        } else {
            out.push('<');
            rest = &candidate[1..];
        }
    }
    out.push_str(rest);
    out
}

#[test]
fn scripts_and_segmenter_fixtures_are_present() {
    let cases = cases();
    assert!(cases.iter().any(|c| c.file == "common/scripts"));
    assert!(cases.iter().any(|c| c.file.starts_with("segmenter/")));
}

#[test]
fn tokens_are_lossless() {
    for fixture in cases() {
        let tokens = tokenize(&fixture.input, &fixture.options());
        let joined: String = tokens.iter().map(Token::text).collect();
        assert_eq!(joined, fixture.input, "{}", fixture.id());
        for token in &tokens {
            if let Token::Word {
                text,
                fixation,
                fixation_text,
                rest_text,
            } = *token
            {
                assert_eq!(
                    format!("{fixation_text}{rest_text}"),
                    text,
                    "{}",
                    fixture.id()
                );
                assert_eq!(fixation == 0, fixation_text.is_empty(), "{}", fixture.id());
            }
        }
    }
}

#[test]
fn a_word_never_starts_with_a_combining_mark() {
    for fixture in cases() {
        for token in tokenize(&fixture.input, &fixture.options()) {
            if let Token::Word { text, .. } = token {
                let first = text.chars().next().expect("words are not empty");
                assert!(
                    !is_mark(first),
                    "{}: word {text:?} starts with a mark",
                    fixture.id()
                );
            }
        }
    }
}

#[test]
fn markup_adds_only_emphasis_tags_and_never_alters_bidi() {
    for fixture in cases() {
        let rendered = fixture.render();
        let tags = fixture.emphasis_tags();
        if !fixture.ignore_html_tags() || !fixture.input.contains(['<', '&']) {
            assert_eq!(
                strip_emphasis(&rendered, &tags),
                escape_html(&fixture.input),
                "{}",
                fixture.id()
            );
        }
        // The same render with every fixation suppressed adds no emphasis tags
        // of its own (the input may already contain some, hence stripping both).
        let plain_options = fixture.options().fixation_length(|_, _, _| 0);
        let plain =
            smooth_reading::to_html(&fixture.input, &plain_options, &fixture.html_options());
        assert_eq!(
            strip_emphasis(&rendered, &tags),
            strip_emphasis(&plain, &tags),
            "{}",
            fixture.id()
        );
        // No direction-changing markup is ever *added*.
        assert_eq!(
            rendered.matches("dir=").count(),
            fixture.input.matches("dir=").count(),
            "{}",
            fixture.id()
        );
        assert_eq!(
            rendered.matches("<bdi").count(),
            fixture.input.matches("<bdi").count(),
            "{}",
            fixture.id()
        );
        let input_controls = fixture
            .input
            .chars()
            .filter(|&c| is_bidi_control(c))
            .count();
        let output_controls = rendered.chars().filter(|&c| is_bidi_control(c)).count();
        assert_eq!(output_controls, input_controls, "{}", fixture.id());
    }
}

fn single_word(text: &str, options: &Options) -> (String, String) {
    let tokens = tokenize(text, options);
    assert_eq!(tokens.len(), 1, "{text:?} is one word");
    match tokens.first() {
        Some(Token::Word {
            fixation_text,
            rest_text,
            ..
        }) => ((*fixation_text).to_owned(), (*rest_text).to_owned()),
        _ => panic!("{text:?} is a separator"),
    }
}

#[test]
fn decomposed_hangul_jamo_compose() {
    // "한글" in NFD: each syllable is a leading consonant, a vowel and a
    // trailing consonant written as separate jamo.
    let decomposed = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}";
    let (prefix, _) = single_word(decomposed, &Options::new().fixation(1));
    assert_eq!(prefix, "\u{1112}\u{1161}\u{11AB}");
}

#[test]
fn indic_conjuncts_are_one_cluster() {
    let options = Options::new();
    assert_eq!(
        single_word("क्षत्रिय", &options),
        ("क्षत्रि".to_owned(), "य".to_owned())
    );
    assert_eq!(single_word("ক্ষমা", &options).0, "ক্ষ"); // Bengali
    assert_eq!(single_word("தமிழ்", &options).0, "தமி"); // Tamil pulli is not a linker
    assert_eq!(
        single_word("उम्र", &options),
        ("उ".to_owned(), "म्र".to_owned())
    ); // an independent vowel does not link
}
