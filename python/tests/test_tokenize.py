"""Tokenizer behaviour from docs/SPEC.md sections 1 and 3."""

from __future__ import annotations

from typing import Any

import pytest

from smooth_reading import Token, tokenize


def texts(text: str, **options: Any) -> list[tuple[str, str]]:
    return [(token.type, token.text) for token in tokenize(text, **options)]


def words(text: str, **options: Any) -> list[Token]:
    return [token for token in tokenize(text, **options) if token.is_word]


def test_round_trip_covers_the_input() -> None:
    text = 'Hello, "world" -- don\'t stop; 42 中文 ok?'
    assert "".join(token.text for token in tokenize(text)) == text


def test_basic_split() -> None:
    assert texts("Smooth reading works.") == [
        ("word", "Smooth"),
        ("separator", " "),
        ("word", "reading"),
        ("separator", " "),
        ("word", "works"),
        ("separator", "."),
    ]


def test_hyphens_separate_words() -> None:
    assert texts("well-known") == [
        ("word", "well"),
        ("separator", "-"),
        ("word", "known"),
    ]


def test_apostrophes_join_words() -> None:
    assert texts("don't") == [("word", "don't")]
    assert texts("don’t") == [("word", "don’t")]
    assert texts("rock 'n' roll") == [
        ("word", "rock"),
        ("separator", " '"),
        ("word", "n"),
        ("separator", "' "),
        ("word", "roll"),
    ]


def test_trailing_apostrophe_is_a_separator() -> None:
    assert texts("dogs'") == [("word", "dogs"), ("separator", "'")]


def test_underscore_is_a_separator_not_a_word_character() -> None:
    assert texts("a_b") == [("word", "a"), ("separator", "_"), ("word", "b")]


def test_word_split_fields() -> None:
    token = words("reading")[0]
    assert token.type == "word"
    assert token.fixation == 4
    assert token.fixation_text == "read"
    assert token.rest_text == "ing"
    assert token.fixation_text + token.rest_text == token.text


def test_separator_tokens_have_no_fixation() -> None:
    separator = tokenize("a b")[1]
    assert separator.type == "separator"
    assert separator.fixation == 0
    assert separator.fixation_text == ""


def test_saccade_counts_word_tokens_only() -> None:
    result = words("one two three four", saccade=2)
    assert [token.fixation > 0 for token in result] == [True, False, True, False]


def test_saccade_counts_numbers_even_though_they_are_not_emphasised() -> None:
    result = words("2024 smooth reading", saccade=2)
    assert [token.fixation for token in result] == [0, 0, 4]


def test_first_word_always_gets_a_fixation() -> None:
    assert words("smooth reading", saccade=9)[0].fixation == 3


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("中文测试", [("word", "中文测试")]),
        ("ひらがな", [("word", "ひらがな")]),
        ("カタカナ", [("word", "カタカナ")]),
        ("한국어", [("word", "한국어")]),
        ("สวัสดี", [("word", "สวัสดี")]),
    ],
)
def test_each_scriptio_continua_run_is_one_word(
    text: str, expected: list[tuple[str, str]]
) -> None:
    assert texts(text) == expected


def test_scriptio_continua_runs_split_from_latin() -> None:
    assert texts("中文abc") == [("word", "中文"), ("word", "abc")]
    assert texts("中文、日本語") == [
        ("word", "中文"),
        ("separator", "、"),
        ("word", "日本語"),
    ]


def test_cjk_run_prefix_length() -> None:
    assert words("中文测试")[0].fixation_text == "中文"
    assert words("中文测试", fixation=5)[0].fixation_text == "中文测"


def test_single_ideograph_is_always_emphasised() -> None:
    # Spec section 3 uses max(1, ...) for runs, with no strength >= 3 gate.
    assert words("中", fixation=1)[0].fixation_text == "中"


def test_thai_marks_stay_with_their_base() -> None:
    token = words("สวัสดี")[0]
    assert token.fixation_text + token.rest_text == token.text
    assert token.fixation == 2
    assert token.fixation_text == "สวั"


def test_options_accept_camel_case_spellings() -> None:
    assert words("the", minWordLength=4)[0].fixation == 0
    assert words("2024", emphasizeNumbers=True)[0].fixation == 2


def test_unknown_option_raises() -> None:
    with pytest.raises(TypeError):
        tokenize("hi", nonsense=1)
