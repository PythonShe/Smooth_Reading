//! Spot checks of the generated Unicode general-category tables.

use smooth_reading::unicode_data::{
    UNICODE_VERSION, is_decimal_digit, is_letter, is_mark, is_number,
};

#[test]
fn letters() {
    for c in ['a', 'Z', 'é', '我', 'ก', 'ß', 'ا', 'א', 'あ', '𠀀'] {
        assert!(is_letter(c), "{c:?} is a letter");
        assert!(
            !is_number(c) && !is_decimal_digit(c) && !is_mark(c),
            "{c:?} is only a letter"
        );
    }
}

#[test]
fn numbers() {
    assert!(
        is_number('٣') && is_decimal_digit('٣'),
        "Arabic-Indic three is Nd"
    );
    assert!(is_number('9') && is_decimal_digit('9'));
    assert!(
        is_number('०') && is_decimal_digit('०'),
        "Devanagari zero is Nd"
    );
    assert!(
        is_number('½') && !is_decimal_digit('½'),
        "vulgar fraction is No"
    );
    assert!(
        is_number('Ⅻ') && !is_decimal_digit('Ⅻ'),
        "Roman numeral is Nl"
    );
    assert!(
        is_number('\u{3007}') && !is_decimal_digit('\u{3007}'),
        "ideographic zero is Nl"
    );
    assert!(
        is_number('²') && !is_decimal_digit('²'),
        "superscript two is No"
    );
    assert!(!is_letter('٣') && !is_mark('٣'));
}

#[test]
fn marks() {
    assert!(is_mark('\u{0301}'), "combining acute is Mn");
    assert!(is_mark('\u{094D}'), "Devanagari virama is Mn");
    assert!(is_mark('\u{0BBF}'), "Tamil vowel sign i is Mc");
    assert!(is_mark('\u{0E31}'), "Thai mai han-akat is Mn");
    assert!(is_mark('\u{FE0F}'), "variation selector 16 is Mn");
    assert!(is_mark('\u{20DD}'), "combining enclosing circle is Me");
    assert!(!is_letter('\u{0301}') && !is_number('\u{0301}'));
}

#[test]
fn neither() {
    for c in [
        '・',
        '_',
        ' ',
        '-',
        '\'',
        '\u{200D}',
        '😀',
        '\n',
        '\u{FFFF}',
        '\u{10FFFF}',
    ] {
        assert!(
            !is_letter(c) && !is_number(c) && !is_decimal_digit(c) && !is_mark(c),
            "{c:?}"
        );
    }
}

#[test]
fn ascii_agrees_with_std() {
    for byte in 0..=0x7Fu8 {
        let c = char::from(byte);
        assert_eq!(is_letter(c), c.is_ascii_alphabetic(), "{c:?}");
        assert_eq!(is_number(c), c.is_ascii_digit(), "{c:?}");
        assert_eq!(is_decimal_digit(c), c.is_ascii_digit(), "{c:?}");
        assert!(!is_mark(c), "{c:?}");
    }
}

#[test]
fn version_is_recorded() {
    assert_eq!(UNICODE_VERSION.split('.').count(), 3, "{UNICODE_VERSION}");
    assert!(
        UNICODE_VERSION
            .chars()
            .all(|c| c.is_ascii_digit() || c == '.')
    );
}
