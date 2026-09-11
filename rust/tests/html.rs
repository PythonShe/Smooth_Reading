//! HTML and Markdown rendering rules from SPEC §4, mirroring the Python port's
//! `test_html.py`.

use smooth_reading::{DEFAULT_SKIP_TAGS, HtmlOptions, Options, escape_html, to_html, to_markdown};

fn html(text: &str) -> String {
    to_html(text, &Options::new(), &HtmlOptions::new())
}

fn html_with(text: &str, options: &Options, html: &HtmlOptions) -> String {
    to_html(text, options, html)
}

#[test]
fn spec_fixture_example() {
    assert_eq!(
        html("Smooth reading works."),
        "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks."
    );
}

#[test]
fn every_strength() {
    let expected = [
        "<b>S</b>mooth <b>r</b>eading",
        "<b>Sm</b>ooth <b>re</b>ading",
        "<b>Smo</b>oth <b>read</b>ing",
        "<b>Smoo</b>th <b>readi</b>ng",
        "<b>Smoot</b>h <b>readin</b>g",
    ];
    for (i, expected) in expected.iter().enumerate() {
        let strength = u8::try_from(i + 1).expect("small");
        assert_eq!(
            &html_with(
                "Smooth reading",
                &Options::new().fixation(strength),
                &HtmlOptions::new()
            ),
            expected
        );
    }
}

#[test]
fn saccade() {
    let h = HtmlOptions::new();
    assert_eq!(
        html_with("Smooth reading works.", &Options::new().saccade(2), &h),
        "<b>Smo</b>oth reading <b>wor</b>ks."
    );
    assert_eq!(
        html_with(
            "one two three four five six",
            &Options::new().saccade(3),
            &h
        ),
        "<b>on</b>e two three <b>fo</b>ur five six"
    );
}

#[test]
fn min_word_length_and_numbers() {
    let h = HtmlOptions::new();
    assert_eq!(
        html_with("a to the read", &Options::new().min_word_length(4), &h),
        "a to the <b>re</b>ad"
    );
    assert_eq!(html("in 2024"), "<b>i</b>n 2024");
    assert_eq!(
        html_with("in 2024", &Options::new().emphasize_numbers(true), &h),
        "<b>i</b>n <b>20</b>24"
    );
}

#[test]
fn hyphen_splits_and_apostrophe_joins() {
    assert_eq!(html("well-known"), "<b>we</b>ll-<b>kno</b>wn");
    assert_eq!(html("don't"), "<b>don</b>'t");
}

#[test]
fn custom_tag_and_classes() {
    let o = Options::new();
    assert_eq!(
        html_with(
            "smooth",
            &o,
            &HtmlOptions::new().tag("span").class_name("sr-fixation")
        ),
        r#"<span class="sr-fixation">smo</span>oth"#
    );
    assert_eq!(
        html_with(
            "smooth",
            &o,
            &HtmlOptions::new()
                .rest_tag("span")
                .rest_class_name("sr-rest")
        ),
        r#"<b>smo</b><span class="sr-rest">oth</span>"#
    );
}

#[test]
fn class_names_are_escaped() {
    assert_eq!(
        html_with(
            "smooth",
            &Options::new(),
            &HtmlOptions::new().class_name("a\"b")
        ),
        r#"<b class="a&quot;b">smo</b>oth"#
    );
}

#[test]
fn empty_class_name_emits_an_empty_attribute() {
    assert_eq!(
        html_with(
            "smooth",
            &Options::new(),
            &HtmlOptions::new().class_name("")
        ),
        r#"<b class="">smo</b>oth"#
    );
}

#[test]
fn rest_tag_omitted_when_the_rest_is_empty() {
    let rest = HtmlOptions::new().rest_tag("span");
    assert_eq!(
        html_with("to", &Options::new().fixation(5), &rest),
        "<b>to</b>"
    );
    assert_eq!(html_with("a", &Options::new(), &rest), "<b>a</b>");
}

#[test]
fn rest_tag_not_used_for_unemphasised_words() {
    assert_eq!(
        html_with(
            "2024 a",
            &Options::new().fixation(2),
            &HtmlOptions::new().rest_tag("span")
        ),
        "2024 a"
    );
}

#[test]
fn escaping_of_emitted_text() {
    assert_eq!(html("say \"hi\""), "<b>sa</b>y &quot;<b>h</b>i&quot;");
    assert_eq!(html("a > b"), "<b>a</b> &gt; <b>b</b>");
    assert_eq!(html("it's"), "<b>it</b>'s"); // the apostrophe is not escaped
    assert_eq!(escape_html("<&>\"'"), "&lt;&amp;&gt;&quot;'");
}

#[test]
fn bare_less_than_is_text() {
    // "<" only starts markup when followed by a letter, "/", "!" or "?".
    assert_eq!(html("a < b"), "<b>a</b> &lt; <b>b</b>");
    assert_eq!(html("x <3 y"), "<b>x</b> &lt;3 <b>y</b>");
    assert_eq!(html("a </ b"), "<b>a</b> &lt;/ <b>b</b>");
    assert_eq!(html("<"), "&lt;");
    assert_eq!(html("<p"), "&lt;<b>p</b>"); // unterminated: not markup
    assert_eq!(html("a <!"), "<b>a</b> &lt;!");
}

#[test]
fn entities_pass_through_and_split_words() {
    assert_eq!(
        html("AT&amp;T rules"),
        "<b>A</b>T&amp;<b>T</b> <b>rul</b>es"
    );
    assert_eq!(html("&#169; 2024 &#x41;"), "&#169; 2024 &#x41;");
    assert_eq!(html("&nbsp;x"), "&nbsp;<b>x</b>");
    assert_eq!(html("&#X1F600;x"), "&#X1F600;<b>x</b>");
}

#[test]
fn bare_ampersand_is_escaped() {
    assert_eq!(html("a & b"), "<b>a</b> &amp; <b>b</b>");
    assert_eq!(html("a &b c"), "<b>a</b> &amp;<b>b</b> <b>c</b>"); // no ";" -> not a reference
    assert_eq!(html("a &; b"), "<b>a</b> &amp;; <b>b</b>");
    assert_eq!(
        html("&#; &#x; &#1x; &1;"),
        "&amp;#; &amp;#<b>x</b>; &amp;#<b>1</b>x; &amp;1;"
    );
    assert_eq!(html("&"), "&amp;");
}

#[test]
fn every_ampersand_is_escaped_when_tags_are_not_ignored() {
    assert_eq!(
        html_with(
            "AT&amp;T & co",
            &Options::new(),
            &HtmlOptions::new().ignore_html_tags(false)
        ),
        "<b>A</b>T&amp;<b>am</b>p;<b>T</b> &amp; <b>c</b>o"
    );
}

#[test]
fn tags_pass_through_verbatim() {
    assert_eq!(
        html(r#"<p class="x">smooth</p>"#),
        r#"<p class="x"><b>smo</b>oth</p>"#
    );
    assert_eq!(html("<!-- smooth -->keep"), "<!-- smooth --><b>ke</b>ep");
    assert_eq!(
        html("<!DOCTYPE html><?xml?>hi"),
        "<!DOCTYPE html><?xml?><b>h</b>i"
    );
    assert_eq!(
        html("a<br/>b<br />c"),
        "<b>a</b><br/><b>b</b><br /><b>c</b>"
    );
    assert_eq!(html("<!-- a\nb -->c"), "<!-- a\nb --><b>c</b>");
}

#[test]
fn attribute_text_is_never_emphasised() {
    assert_eq!(html(r#"<img alt="reading">"#), r#"<img alt="reading">"#);
    assert_eq!(
        html(r#"<a href="x/y">go</a>"#),
        r#"<a href="x/y"><b>g</b>o</a>"#
    );
}

#[test]
fn default_skip_tags() {
    for tag in DEFAULT_SKIP_TAGS {
        let input = format!("<{tag}>smooth reading</{tag}> smooth");
        assert_eq!(
            html(&input),
            format!("<{tag}>smooth reading</{tag}> <b>smo</b>oth")
        );
    }
}

#[test]
fn skip_tags_are_case_insensitive_and_accept_attributes() {
    assert_eq!(html("<CODE>smooth</CODE>"), "<CODE>smooth</CODE>");
    assert_eq!(
        html(r#"<pre class="x">smooth</pre>"#),
        r#"<pre class="x">smooth</pre>"#
    );
    assert_eq!(
        html_with(
            "<Em>smooth</EM>",
            &Options::new(),
            &HtmlOptions::new().skip_tags(["eM"])
        ),
        "<Em>smooth</EM>"
    );
}

#[test]
fn skip_tags_are_nesting_aware() {
    assert_eq!(
        html("<pre>a <code>b</code> c</pre> d"),
        "<pre>a <code>b</code> c</pre> <b>d</b>"
    );
    assert_eq!(
        html("<pre>x <pre>y</pre> z</pre> d"),
        "<pre>x <pre>y</pre> z</pre> <b>d</b>"
    );
    // A stray closing tag outside any skip element is harmless.
    assert_eq!(html("</code> ok"), "</code> <b>o</b>k");
}

#[test]
fn self_closing_skip_tag_does_not_open_a_skip() {
    assert_eq!(html("<code/>smooth"), "<code/><b>smo</b>oth");
}

#[test]
fn skipped_content_is_not_escaped() {
    assert_eq!(html("<code>a < b & c</code>"), "<code>a < b & c</code>");
    // An unterminated skip element runs to the end of the input.
    assert_eq!(html("<pre>a & b"), "<pre>a & b");
}

#[test]
fn saccade_counting_continues_across_tags() {
    assert_eq!(
        html_with(
            "one <em>two</em> three",
            &Options::new().saccade(2),
            &HtmlOptions::new()
        ),
        "<b>on</b>e <em>two</em> <b>thr</b>ee"
    );
}

#[test]
fn skipped_words_do_not_consume_a_saccade_index() {
    assert_eq!(
        html_with(
            "one <code>two</code> three",
            &Options::new().saccade(2),
            &HtmlOptions::new()
        ),
        "<b>on</b>e <code>two</code> three"
    );
}

#[test]
fn custom_skip_tags_replace_the_default() {
    let em = HtmlOptions::new().skip_tags(["em"]);
    assert_eq!(
        html_with("<em>smooth</em>", &Options::new(), &em),
        "<em>smooth</em>"
    );
    assert_eq!(
        html_with("<code>smooth</code>", &Options::new(), &em),
        "<code><b>smo</b>oth</code>"
    );
}

#[test]
fn emphasis_tags_are_implicitly_skipped() {
    assert_eq!(
        html("<b>Smooth</b> reading"),
        "<b>Smooth</b> <b>read</b>ing"
    );
    let spans = HtmlOptions::new()
        .tag("span")
        .class_name("f")
        .rest_tag("span");
    let once = html_with("Smooth reading", &Options::new(), &spans);
    assert_eq!(html_with(&once, &Options::new(), &spans), once);
    assert_eq!(html("<span>Smooth</span>"), "<span><b>Smo</b>oth</span>");
}

#[test]
fn ignore_html_tags_false_escapes_everything() {
    let plain = HtmlOptions::new().ignore_html_tags(false);
    assert_eq!(
        html_with("<p>smooth</p>", &Options::new(), &plain),
        "&lt;<b>p</b>&gt;<b>smo</b>oth&lt;/<b>p</b>&gt;"
    );
    assert_eq!(
        html_with(
            "<code>x</code>",
            &Options::new(),
            &plain.clone().skip_tags(["code"])
        ),
        "&lt;<b>co</b>de&gt;<b>x</b>&lt;/<b>co</b>de&gt;"
    );
}

#[test]
fn fixation_length_override() {
    assert_eq!(
        html_with(
            "smooth reading",
            &Options::new().fixation_length(|_, _, _| 1),
            &HtmlOptions::new()
        ),
        "<b>s</b>mooth <b>r</b>eading"
    );
}

#[test]
fn markdown_output() {
    assert_eq!(
        to_markdown("Smooth reading works.", &Options::new(), "**"),
        "**Smo**oth **read**ing **wor**ks."
    );
    assert_eq!(
        to_markdown("in 2024", &Options::new().saccade(2), "**"),
        "**i**n 2024"
    );
    assert_eq!(to_markdown("smooth", &Options::new(), "__"), "__smo__oth");
}

#[test]
fn markdown_does_not_escape() {
    assert_eq!(
        to_markdown("a < b & c", &Options::new(), "**"),
        "**a** < **b** & **c**"
    );
}

// --- tag-name grammar (matches the core's markup lexer) --------------------

#[test]
fn a_tag_name_runs_until_whitespace_slash_or_gt() {
    // <code.x> is named "code.x", so it is not the skip tag "code".
    assert_eq!(
        html("<code.x>hello</code.x>"),
        "<code.x><b>hel</b>lo</code.x>"
    );
}

#[test]
fn a_space_after_the_slash_still_closes_a_tag() {
    assert_eq!(html("<code>a</ code>b"), "<code>a</ code><b>b</b>");
}

#[test]
fn a_spaced_self_closing_tag_does_not_open_a_skip() {
    assert_eq!(
        html("<code / >hello</code>"),
        "<code / ><b>hel</b>lo</code>"
    );
    assert_eq!(html("<code/ >hello</code>"), "<code/ ><b>hel</b>lo</code>");
}

#[test]
fn a_cdata_section_passes_through_with_its_bare_angle_bracket() {
    assert_eq!(
        html("x <![CDATA[ a > b ]]> y"),
        "<b>x</b> <![CDATA[ a > b ]]> <b>y</b>"
    );
}

#[test]
fn an_unterminated_comment_ends_at_the_first_gt() {
    assert_eq!(html("a <!-- b > c"), "<b>a</b> <!-- b > <b>c</b>");
    assert_eq!(html("a <![CDATA[ b > c"), "<b>a</b> <![CDATA[ b > <b>c</b>");
    assert_eq!(html("a <!-- b c"), "<b>a</b> &lt;!-- <b>b</b> <b>c</b>");
}

#[test]
fn comment_delimiters_do_not_overlap() {
    // "<!-->" is not a complete comment; it degrades to a declaration.
    assert_eq!(html("<!-->x"), "<!--><b>x</b>");
    assert_eq!(html("<!---->x"), "<!----><b>x</b>");
}

#[test]
fn markup_without_a_tag_name_still_passes_through_verbatim() {
    assert_eq!(html("a </> b"), "<b>a</b> </> <b>b</b>");
}

#[test]
fn non_ascii_text_around_markup() {
    assert_eq!(
        html("<p>我喜欢阅读</p> <em>naïve</em>"),
        "<p><b>我喜欢</b>阅读</p> <em><b>naï</b>ve</em>"
    );
}
