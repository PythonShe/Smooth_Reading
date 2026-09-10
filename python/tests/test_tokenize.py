"""Tokenizer behaviour from docs/SPEC.md sections 1, 3 and 4."""

from __future__ import annotations

from typing import Any

import pytest

from smooth_reading import Options, Token, tokenize


def texts(text: str, **options: Any) -> list[tuple[str, str]]:
    return [(token.type, token.text) for token in tokenize(text, **options)]


def words(text: str, options: Options | None = None, **overrides: Any) -> list[Token]:
    return [token for token in tokenize(text, options, **overrides) if token.type == "word"]


def test_round_trip_covers_the_input() -> None:
    text = 'Hello, "world" -- don\'t stop; 42 中文 ok?\r\n'
    assert "".join(token.text for token in tokenize(text)) == text


def test_empty_input() -> None:
    assert tokenize("") == []


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
    assert texts("well-known") == [("word", "well"), ("separator", "-"), ("word", "known")]


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


def test_trailing_and_doubled_apostrophes_are_separators() -> None:
    assert texts("dogs'") == [("word", "dogs"), ("separator", "'")]
    assert texts("a''b") == [("word", "a"), ("separator", "''"), ("word", "b")]


def test_underscore_and_decimal_point_are_separators() -> None:
    # \w would match "_"; the spec class [\p{L}\p{N}\p{M}] does not.
    assert texts("a_b") == [("word", "a"), ("separator", "_"), ("word", "b")]
    assert texts("3.14") == [("word", "3"), ("separator", "."), ("word", "14")]


def test_word_split_fields() -> None:
    token = words("reading")[0]
    assert token == Token("word", "reading", 4, "read", "ing")
    assert token.fixation_text + token.rest_text == token.text


def test_unemphasised_word_has_empty_prefix() -> None:
    assert words("2024")[0] == Token("word", "2024", 0, "", "2024")


def test_separator_tokens_have_no_fixation() -> None:
    assert tokenize("a b")[1] == Token("separator", " ")


def test_saccade_counts_word_tokens_only() -> None:
    result = words("one, two; three four", saccade=2)
    assert [token.fixation > 0 for token in result] == [True, False, True, False]


def test_saccade_counts_numbers_even_though_they_are_not_emphasised() -> None:
    assert [token.fixation for token in words("2024 smooth reading", saccade=2)] == [0, 0, 4]


def test_first_word_always_gets_a_fixation() -> None:
    assert words("smooth reading", saccade=9)[0].fixation == 3


@pytest.mark.parametrize("text", ["中文测试", "ひらがな", "カタカナ", "한국어"])
def test_each_cjk_run_is_one_word(text: str) -> None:
    assert texts(text) == [("word", text)]


def test_cjk_runs_split_from_latin_and_punctuation() -> None:
    assert texts("中文abc") == [("word", "中文"), ("word", "abc")]
    assert texts("中文、日本語") == [("word", "中文"), ("separator", "、"), ("word", "日本語")]
    assert texts("アイ・ウエ") == [("word", "アイ"), ("separator", "・"), ("word", "ウエ")]


def test_cjk_run_prefix_length() -> None:
    assert words("中文测试")[0].fixation_text == "中文"
    assert words("中文测试", fixation=5)[0].fixation_text == "中文测"


def test_single_ideograph_follows_the_single_character_rule() -> None:
    # Spec section 2 rule 3 applies to every script: one character needs strength >= 3.
    assert words("中", fixation=2)[0].fixation == 0
    assert words("中", fixation=3)[0].fixation_text == "中"


def test_thai_is_one_word_and_marks_stay_with_their_base() -> None:
    token = words("สวัสดี")[0]
    assert token.text == "สวัสดี"
    assert token.fixation == 2
    assert token.fixation_text == "สวั"
    assert token.fixation_text + token.rest_text == token.text


def test_options_instance_and_keywords_combine() -> None:
    assert words("the", Options(min_word_length=4))[0].fixation == 0
    assert words("the", Options(min_word_length=4), min_word_length=1)[0].fixation == 2


def test_unknown_option_raises_type_error() -> None:
    with pytest.raises(TypeError, match="nonsense"):
        tokenize("hi", nonsense=1)


def test_wrong_type_keyword_value_raises_value_error() -> None:
    with pytest.raises(ValueError, match="saccade"):
        tokenize("hi", saccade="0")


def test_out_of_range_keyword_value_is_clamped() -> None:
    # saccade 0 clamps to 1: every word is emphasised, exactly as with saccade=1.
    assert tokenize("hi there", saccade=0) == tokenize("hi there", saccade=1)
    assert tokenize("hi there", fixation=7) == tokenize("hi there", fixation=5)
