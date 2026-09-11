//! `Options` and `HtmlOptions` builders, defaults and clamping (SPEC §4).

use std::sync::Arc;

use smooth_reading::{
    DEFAULT_SKIP_TAGS, HtmlOptions, Options, Segmenter, SpecSegmenter, VERSION, fixation_length,
};

#[test]
fn defaults_match_the_spec() {
    let options = Options::new();
    assert_eq!(options.get_fixation(), 3);
    assert_eq!(options.get_saccade(), 1);
    assert_eq!(options.get_min_word_length(), 1);
    assert!(!options.get_emphasize_numbers());
    assert_eq!(options.get_locale(), None);
    assert!(options.get_fixation_length().is_none());
    assert!(options.get_segmenter().is_none());
    assert!((options.ratio() - 0.5).abs() < f64::EPSILON);
}

#[test]
fn default_trait_equals_new() {
    let a = format!("{:?}", Options::default());
    let b = format!("{:?}", Options::new());
    assert_eq!(a, b);
}

#[test]
fn fixation_is_clamped_to_one_through_five() {
    assert_eq!(Options::new().fixation(0).get_fixation(), 1);
    assert_eq!(Options::new().fixation(1).get_fixation(), 1);
    assert_eq!(Options::new().fixation(5).get_fixation(), 5);
    assert_eq!(Options::new().fixation(9).get_fixation(), 5);
    assert_eq!(Options::new().fixation(u8::MAX).get_fixation(), 5);
}

#[test]
fn saccade_is_clamped_to_at_least_one() {
    assert_eq!(Options::new().saccade(0).get_saccade(), 1);
    assert_eq!(Options::new().saccade(7).get_saccade(), 7);
}

#[test]
fn ratio_follows_the_table() {
    let ratios: Vec<f64> = (1..=5)
        .map(|s| Options::new().fixation(s).ratio())
        .collect();
    assert_eq!(ratios, [0.2, 0.35, 0.5, 0.65, 0.8]);
}

#[test]
fn setters_chain_and_getters_read_back() {
    let options = Options::new()
        .fixation(2)
        .saccade(3)
        .min_word_length(4)
        .emphasize_numbers(true)
        .locale("zh-Hans")
        .fixation_length(|_, n, _| n)
        .segmenter(SpecSegmenter);
    assert_eq!(options.get_fixation(), 2);
    assert_eq!(options.get_saccade(), 3);
    assert_eq!(options.get_min_word_length(), 4);
    assert!(options.get_emphasize_numbers());
    assert_eq!(options.get_locale(), Some("zh-Hans"));
    assert!(options.get_fixation_length().is_some());
    assert!(options.get_segmenter().is_some());
    let cloned = options.clone();
    assert_eq!(cloned.get_saccade(), 3);
}

#[test]
fn debug_output_names_the_fields() {
    let debug = format!(
        "{:?}",
        Options::new().fixation(4).fixation_length(|_, _, _| 1)
    );
    assert!(debug.starts_with("Options {"), "{debug}");
    assert!(debug.contains("fixation: 4"), "{debug}");
    assert!(
        debug.contains("fixation_length: Some(\"<custom>\")"),
        "{debug}"
    );
    assert!(debug.contains("segmenter: None"), "{debug}");
}

#[test]
fn custom_fixation_length_is_clamped_to_the_word() {
    let options = Options::new().fixation_length(|_, _, _| 99);
    assert_eq!(fixation_length("read", 4, &options), 4);
    let options = Options::new().fixation_length(|word, n, o| {
        if word == "skip" {
            0
        } else {
            n / 2 + o.get_saccade()
        }
    });
    assert_eq!(fixation_length("skip", 4, &options), 0);
    assert_eq!(fixation_length("reading", 7, &options), 4);
}

#[test]
fn builtin_fixation_length_rules_in_order() {
    let options = Options::new();
    assert_eq!(fixation_length("", 0, &options), 0);
    assert_eq!(
        fixation_length("٣٤", 2, &options),
        0,
        "Arabic-Indic digits are Nd"
    );
    assert_eq!(
        fixation_length("٣٤", 2, &options.clone().emphasize_numbers(true)),
        1
    );
    assert_eq!(
        fixation_length("½", 1, &options),
        1,
        "a fraction is No, not a digit word"
    );
    assert_eq!(
        fixation_length("abc", 3, &options.clone().min_word_length(4)),
        0
    );
    assert_eq!(fixation_length("a", 1, &options.clone().fixation(2)), 0);
    assert_eq!(fixation_length("a", 1, &options.clone().fixation(3)), 1);
    let by_strength: Vec<usize> = (1..=5)
        .map(|s| fixation_length("reading", 7, &options.clone().fixation(s)))
        .collect();
    assert_eq!(by_strength, [1, 2, 4, 5, 6]);
    assert_eq!(
        fixation_length("to", 2, &options.clone().fixation(1)),
        1,
        "clamped up to 1"
    );
}

#[test]
fn absurd_grapheme_counts_do_not_overflow() {
    let options = Options::new();
    assert_eq!(fixation_length("x", usize::MAX, &options), usize::MAX);
    assert_eq!(
        fixation_length("x", usize::MAX / 2, &options.clone().fixation(5)),
        usize::MAX / 2
    );
    let large = usize::MAX / 100; // still multiplies without overflowing
    assert_eq!(
        fixation_length("x", large, &options),
        (large * 50 + 50) / 100
    );
}

#[test]
fn a_shared_segmenter_is_reused_across_options() {
    let shared: Arc<dyn Segmenter> = Arc::new(SpecSegmenter);
    let a = Options::new().shared_segmenter(Arc::clone(&shared));
    let b = Options::new()
        .fixation(5)
        .shared_segmenter(Arc::clone(&shared));
    assert_eq!(Arc::strong_count(&shared), 3);
    assert!(a.get_segmenter().is_some() && b.get_segmenter().is_some());
    assert_eq!(
        smooth_reading::to_markdown("iPhone手机", &a, "**"),
        smooth_reading::to_markdown("iPhone手机", &Options::new(), "**")
    );
}

#[test]
fn html_options_defaults() {
    let html = HtmlOptions::new();
    assert_eq!(html.get_tag(), "b");
    assert_eq!(html.get_class_name(), None);
    assert_eq!(html.get_rest_tag(), None);
    assert_eq!(html.get_rest_class_name(), None);
    assert!(html.get_ignore_html_tags());
    assert_eq!(html.get_skip_tags(), DEFAULT_SKIP_TAGS);
    assert_eq!(HtmlOptions::default(), html);
}

#[test]
fn html_options_setters() {
    let html = HtmlOptions::new()
        .tag("span")
        .class_name("f")
        .rest_tag("span")
        .rest_class_name("r")
        .ignore_html_tags(false)
        .skip_tags(["em", "strong"]);
    assert_eq!(html.get_tag(), "span");
    assert_eq!(html.get_class_name(), Some("f"));
    assert_eq!(html.get_rest_tag(), Some("span"));
    assert_eq!(html.get_rest_class_name(), Some("r"));
    assert!(!html.get_ignore_html_tags());
    assert_eq!(html.get_skip_tags(), ["em", "strong"]);
}

#[test]
fn version_matches_the_manifest() {
    assert_eq!(VERSION, env!("CARGO_PKG_VERSION"));
    assert_eq!(VERSION, "0.3.0");
}
