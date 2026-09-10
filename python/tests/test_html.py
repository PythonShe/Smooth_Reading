"""HTML and Markdown rendering rules from docs/SPEC.md section 4."""

from __future__ import annotations

import pytest

from smooth_reading import SKIP_TAGS, Options, to_html, to_markdown


def test_spec_fixture_example() -> None:
    assert to_html("Smooth reading works.", fixation=3) == (
        "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks."
    )


def test_defaults_and_determinism() -> None:
    text = "Smooth reading works."
    assert to_html(text) == to_html(text, Options()) == to_html(text, fixation=3)


@pytest.mark.parametrize(
    ("strength", "expected"),
    [
        (1, "<b>S</b>mooth <b>r</b>eading"),
        (2, "<b>Sm</b>ooth <b>re</b>ading"),
        (3, "<b>Smo</b>oth <b>read</b>ing"),
        (4, "<b>Smoo</b>th <b>readi</b>ng"),
        (5, "<b>Smoot</b>h <b>readin</b>g"),
    ],
)
def test_every_strength(strength: int, expected: str) -> None:
    assert to_html("Smooth reading", fixation=strength) == expected


def test_saccade() -> None:
    assert to_html("Smooth reading works.", saccade=2) == "<b>Smo</b>oth reading <b>wor</b>ks."
    assert to_html("one two three four five six", saccade=3) == (
        "<b>on</b>e two three <b>fo</b>ur five six"
    )


def test_min_word_length_and_numbers() -> None:
    assert to_html("a to the read", min_word_length=4) == "a to the <b>re</b>ad"
    assert to_html("in 2024") == "<b>i</b>n 2024"
    assert to_html("in 2024", emphasize_numbers=True) == "<b>i</b>n <b>20</b>24"


def test_hyphen_splits_and_apostrophe_joins() -> None:
    assert to_html("well-known") == "<b>we</b>ll-<b>kno</b>wn"
    assert to_html("don't") == "<b>don</b>'t"


def test_custom_tag_and_classes() -> None:
    assert to_html("smooth", tag="span", class_name="sr-fixation") == (
        '<span class="sr-fixation">smo</span>oth'
    )
    assert to_html("smooth", rest_tag="span", rest_class_name="sr-rest") == (
        '<b>smo</b><span class="sr-rest">oth</span>'
    )


def test_class_names_are_escaped() -> None:
    assert to_html("smooth", class_name='a"b') == '<b class="a&quot;b">smo</b>oth'


def test_rest_tag_omitted_when_the_rest_is_empty() -> None:
    assert to_html("to", fixation=5, rest_tag="span") == "<b>to</b>"
    assert to_html("a", rest_tag="span") == "<b>a</b>"


def test_rest_tag_not_used_for_unemphasised_words() -> None:
    assert to_html("2024 a", fixation=2, rest_tag="span") == "2024 a"


def test_escaping_of_emitted_text() -> None:
    assert to_html('say "hi"') == "<b>sa</b>y &quot;<b>h</b>i&quot;"
    assert to_html("a > b") == "<b>a</b> &gt; <b>b</b>"
    assert to_html("it's") == "<b>it</b>'s"  # the apostrophe is not escaped


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("a < b", "<b>a</b> &lt; <b>b</b>"),
        ("x <3 y", "<b>x</b> &lt;3 <b>y</b>"),
        ("a </ b", "<b>a</b> &lt;/ <b>b</b>"),
        ("<", "&lt;"),
        ("<p", "&lt;<b>p</b>"),  # unterminated: not markup
    ],
)
def test_bare_less_than_is_text(text: str, expected: str) -> None:
    # Spec: "<" only starts markup when followed by a letter, "/", "!" or "?".
    assert to_html(text) == expected


def test_entities_pass_through_and_split_words() -> None:
    assert to_html("AT&amp;T rules") == "<b>A</b>T&amp;<b>T</b> <b>rul</b>es"
    assert to_html("&#169; 2024 &#x41;") == "&#169; 2024 &#x41;"
    assert to_html("&nbsp;x") == "&nbsp;<b>x</b>"


def test_bare_ampersand_is_escaped() -> None:
    assert to_html("a & b") == "<b>a</b> &amp; <b>b</b>"
    assert to_html("a &b c") == "<b>a</b> &amp;<b>b</b> <b>c</b>"  # no ";" -> not a reference
    assert to_html("a &; b") == "<b>a</b> &amp;; <b>b</b>"


def test_every_ampersand_is_escaped_when_tags_are_not_ignored() -> None:
    assert to_html("AT&amp;T & co", ignore_html_tags=False) == (
        "<b>A</b>T&amp;<b>am</b>p;<b>T</b> &amp; <b>c</b>o"
    )


def test_tags_pass_through_verbatim() -> None:
    assert to_html('<p class="x">smooth</p>') == '<p class="x"><b>smo</b>oth</p>'
    assert to_html("<!-- smooth -->keep") == "<!-- smooth --><b>ke</b>ep"
    assert to_html("<!DOCTYPE html><?xml?>hi") == "<!DOCTYPE html><?xml?><b>h</b>i"
    assert to_html("a<br/>b<br />c") == "<b>a</b><br/><b>b</b><br /><b>c</b>"


def test_attribute_text_is_never_emphasised() -> None:
    assert to_html('<img alt="reading">') == '<img alt="reading">'
    assert to_html('<a href="x/y">go</a>') == '<a href="x/y"><b>g</b>o</a>'


@pytest.mark.parametrize("tag", SKIP_TAGS)
def test_default_skip_tags(tag: str) -> None:
    html = f"<{tag}>smooth reading</{tag}> smooth"
    assert to_html(html) == f"<{tag}>smooth reading</{tag}> <b>smo</b>oth"


def test_skip_tags_are_case_insensitive_and_accept_attributes() -> None:
    assert to_html("<CODE>smooth</CODE>") == "<CODE>smooth</CODE>"
    assert to_html('<pre class="x">smooth</pre>') == '<pre class="x">smooth</pre>'


def test_skip_tags_are_nesting_aware() -> None:
    assert to_html("<pre>a <code>b</code> c</pre> d") == "<pre>a <code>b</code> c</pre> <b>d</b>"
    assert to_html("<pre>x <pre>y</pre> z</pre> d") == "<pre>x <pre>y</pre> z</pre> <b>d</b>"


def test_self_closing_skip_tag_does_not_open_a_skip() -> None:
    assert to_html("<code/>smooth") == "<code/><b>smo</b>oth"


def test_skipped_content_is_not_escaped() -> None:
    assert to_html("<code>a < b & c</code>") == "<code>a < b & c</code>"


def test_saccade_counting_continues_across_tags() -> None:
    assert to_html("one <em>two</em> three", saccade=2) == "<b>on</b>e <em>two</em> <b>thr</b>ee"


def test_skipped_words_do_not_consume_a_saccade_index() -> None:
    assert to_html("one <code>two</code> three", saccade=2) == "<b>on</b>e <code>two</code> three"


def test_custom_skip_tags_replace_the_default() -> None:
    assert to_html("<em>smooth</em>", skip_tags=["em"]) == "<em>smooth</em>"
    assert to_html("<code>smooth</code>", skip_tags=["em"]) == "<code><b>smo</b>oth</code>"


def test_emphasis_tags_are_implicitly_skipped() -> None:
    # Spec section 4: already emphasised markup is never nested.
    assert to_html("<b>Smooth</b> reading") == "<b>Smooth</b> <b>read</b>ing"
    once = to_html("Smooth reading", tag="span", class_name="f", rest_tag="span")
    assert to_html(once, tag="span", class_name="f", rest_tag="span") == once
    assert to_html("<span>Smooth</span>") == "<span><b>Smo</b>oth</span>"


def test_ignore_html_tags_false_escapes_everything() -> None:
    assert to_html("<p>smooth</p>", ignore_html_tags=False) == (
        "&lt;<b>p</b>&gt;<b>smo</b>oth&lt;/<b>p</b>&gt;"
    )
    assert to_html("<code>x</code>", ignore_html_tags=False, skip_tags=["code"]) == (
        "&lt;<b>co</b>de&gt;<b>x</b>&lt;/<b>co</b>de&gt;"
    )


def test_options_instance_and_keywords_combine() -> None:
    assert to_html("smooth", Options(fixation=5)) == "<b>smoot</b>h"
    assert to_html("smooth", Options(fixation=5), fixation=1) == "<b>s</b>mooth"


def test_fixation_length_override() -> None:
    assert to_html("smooth reading", fixation_length=lambda w, n, o: 1) == (
        "<b>s</b>mooth <b>r</b>eading"
    )


def test_markdown_output() -> None:
    assert to_markdown("Smooth reading works.") == "**Smo**oth **read**ing **wor**ks."
    assert to_markdown("in 2024", Options(saccade=2)) == "**i**n 2024"
    assert to_markdown("smooth", marker="__") == "__smo__oth"


def test_markdown_does_not_escape() -> None:
    assert to_markdown("a < b & c") == "**a** < **b** & **c**"
