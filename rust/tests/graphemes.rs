//! Grapheme clustering of the spec segmenter (SPEC §3, "Grapheme cluster
//! resolution").

use smooth_reading::{Segmenter, SpecSegmenter};

fn graphemes(text: &str) -> Vec<&str> {
    SpecSegmenter.graphemes(text, None)
}

#[test]
fn empty_text_has_no_clusters() {
    assert!(graphemes("").is_empty());
}

#[test]
fn plain_characters_are_one_cluster_each() {
    assert_eq!(graphemes("abc"), ["a", "b", "c"]);
    assert_eq!(graphemes("中文"), ["中", "文"]);
}

#[test]
fn combining_marks_join_their_base() {
    assert_eq!(
        graphemes("nai\u{0308}ve"),
        ["n", "a", "i\u{0308}", "v", "e"]
    );
    assert_eq!(graphemes("e\u{0301}\u{0327}"), ["e\u{0301}\u{0327}"]);
    // A variation selector is a mark too.
    assert_eq!(graphemes("❤\u{FE0F}"), ["❤\u{FE0F}"]);
}

#[test]
fn a_leading_mark_is_its_own_cluster() {
    assert_eq!(graphemes("\u{0301}a"), ["\u{0301}", "a"]);
}

#[test]
fn zwj_joins_the_following_character() {
    assert_eq!(
        graphemes("👨\u{200D}👩\u{200D}👧"),
        ["👨\u{200D}👩\u{200D}👧"]
    );
    // A trailing ZWJ joins nothing but stays in the cluster.
    assert_eq!(graphemes("a\u{200D}"), ["a\u{200D}"]);
}

#[test]
fn cr_lf_is_one_cluster() {
    assert_eq!(graphemes("a\r\nb"), ["a", "\r\n", "b"]);
    assert_eq!(graphemes("\n\r"), ["\n", "\r"]);
}

#[test]
fn decomposed_hangul_composes_into_syllables() {
    // 한글 as L V T jamo sequences.
    let text = "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}";
    assert_eq!(
        graphemes(text),
        ["\u{1112}\u{1161}\u{11AB}", "\u{1100}\u{1173}\u{11AF}"]
    );
    // A precomposed LV syllable takes a trailing jamo.
    assert_eq!(graphemes("\u{D55C}\u{11AB}"), ["\u{D55C}\u{11AB}"]);
    // Two precomposed syllables stay apart.
    assert_eq!(graphemes("한글"), ["한", "글"]);
    // A trailing consonant does not join a following leading consonant.
    assert_eq!(graphemes("\u{11AB}\u{1100}"), ["\u{11AB}", "\u{1100}"]);
}

#[test]
fn indic_conjuncts_link_across_a_virama() {
    assert_eq!(graphemes("क्ष"), ["क्ष"]);
    assert_eq!(graphemes("क्षत्रिय"), ["क्ष", "त्रि", "य"]);
    assert_eq!(graphemes("ক্ষমা"), ["ক্ষ", "মা"]); // Bengali
    // Tamil pulli is not a GB9c linker.
    assert_eq!(graphemes("தமிழ்"), ["த", "மி", "ழ்"]);
    // An independent vowel is not a consonant, so nothing links to it.
    assert_eq!(graphemes("उम्र"), ["उ", "म्र"]);
}

#[test]
fn thai_vowel_signs_join_their_consonant() {
    assert_eq!(graphemes("สวัสดี"), ["ส", "วั", "ส", "ดี"]);
}

#[test]
fn clusters_are_slices_of_the_input() {
    let text = "a\u{0301}b👨\u{200D}👩";
    let joined: String = graphemes(text).concat();
    assert_eq!(joined, text);
}
