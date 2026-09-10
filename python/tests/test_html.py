"""HTML rendering rules from docs/SPEC.md section 4."""

from __future__ import annotations

import pytest

from smooth_reading import Options, to_html, to_markdown


def test_spec_fixture_example() -> None:
    assert to_html("Smooth reading works.", fixation=3) == (
        "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks."
    )


def test_default_options() -> None:
    assert to_html("Smooth reading works.") == to_html("Smooth reading works.", fixation=3)


def test_output_is_stable() -> None:
    text = "Smooth reading works."
    assert to_html(text) == to_html(text)


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


def test_saccade_skips_words_but_keeps_text() -> None:
    assert to_html("Smooth reading works.", saccade=2) == (
        "<b>Smo</b>oth reading <b>wor</b>ks."
    )


def test_saccade_three() -> None:
    assert to_html("one two three four five six", saccade=3) == (
        "<b>on</b>e two three <b>fo</b>ur five six"
    )


def test_min_word_length() -> None:
    assert to_html("a to the read", min_word_length=4) == "a to the <b>re</b>ad"


def test_numbers() -> None:
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


def test_rest_tag_omitted_when_the_whole_word_is_emphasised() -> None:
    assert to_html("to", fixation=5, rest_tag="span") == "<b>to</b>"


def test_escaping_of_emitted_text() -> None:
    assert to_html('a < b') == "<b>a</b> &lt; <b>b</b>"
    assert to_html('say "hi"') == '<b>sa</b>y &quot;<b>h</b>i&quot;'
    assert to_html("a > b") == "<b>a</b> &gt; <b>b</b>"


def test_entities_pass_through() -> None:
    # The entity is a raw chunk, so it splits "AT&amp;T" into two words.
    assert to_html("AT&amp;T rules") == "<b>A</b>T&amp;<b>T</b> <b>rul</b>es"
    assert to_html("&#169; 2024 &#x41;") == "&#169; 2024 &#x41;"


def test_bare_ampersand_is_escaped() -> None:
    assert to_html("a & b") == "<b>a</b> &amp; <b>b</b>"


def test_tags_pass_through_verbatim() -> None:
    assert to_html('<p class="x">smooth</p>') == '<p class="x"><b>smo</b>oth</p>'
    assert to_html("<!-- smooth -->keep") == "<!-- smooth --><b>ke</b>ep"


def test_attribute_text_is_never_emphasised() -> None:
    assert to_html('<img alt="reading">') == '<img alt="reading">'


@pytest.mark.parametrize("tag", ["code", "pre", "script", "style", "kbd", "samp", "textarea"])
def test_skip_tags(tag: str) -> None:
    html = f"<{tag}>smooth reading</{tag}> smooth"
    assert to_html(html) == f"<{tag}>smooth reading</{tag}> <b>smo</b>oth"


def test_skip_tags_are_case_insensitive() -> None:
    assert to_html("<CODE>smooth</CODE>") == "<CODE>smooth</CODE>"


def test_skip_tags_are_nesting_aware() -> None:
    assert to_html("<pre>a <code>b</code> c</pre> d") == "<pre>a <code>b</code> c</pre> <b>d</b>"
    assert to_html("<pre>x <pre>y</pre> z</pre> d") == "<pre>x <pre>y</pre> z</pre> <b>d</b>"


def test_skipped_content_is_not_escaped() -> None:
    assert to_html("<code>a < b & c</code>") == "<code>a < b & c</code>"


def test_saccade_counting_continues_across_tags() -> None:
    assert to_html("one <em>two</em> three", saccade=2) == (
        "<b>on</b>e <em>two</em> <b>thr</b>ee"
    )


def test_custom_skip_tags() -> None:
    assert to_html("<em>smooth</em>", skip_tags=["em"]) == "<em>smooth</em>"


def test_ignore_html_tags_false_escapes_everything() -> None:
    assert to_html("<p>smooth</p>", ignore_html_tags=False) == (
        "&lt;<b>p</b>&gt;<b>smo</b>oth&lt;/<b>p</b>&gt;"
    )


def test_options_object_is_accepted() -> None:
    assert to_html("smooth", options=Options(fixation=5)) == "<b>smoot</b>h"


def test_fixation_length_override() -> None:
    assert to_html("smooth reading", fixation_length=lambda w, n, o: 1) == (
        "<b>s</b>mooth <b>r</b>eading"
    )


def test_markdown_output() -> None:
    assert to_markdown("Smooth reading works.") == "**Smo**oth **read**ing **wor**ks."
    assert to_markdown("in 2024") == "**i**n 2024"


def test_markdown_does_not_escape() -> None:
    assert to_markdown("a < b") == "**a** < **b**"
