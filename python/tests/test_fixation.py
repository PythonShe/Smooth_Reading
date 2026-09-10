"""Hand-derived cases from the tables in docs/SPEC.md section 2."""

from __future__ import annotations

from typing import Any

import pytest

from smooth_reading import DEFAULTS, Options, fixation_length, round_half_up
from smooth_reading.graphemes import grapheme_count


def fx(word: str, **options: Any) -> int:
    opts = DEFAULTS.replace(**options)
    return fixation_length(word, grapheme_count(word), opts)


@pytest.mark.parametrize(
    ("value", "expected"),
    [(0.5, 1), (1.5, 2), (2.5, 3), (-0.5, 0), (0.49, 0), (3.4999, 3)],
)
def test_round_half_up_is_not_bankers(value: float, expected: int) -> None:
    assert round_half_up(value) == expected


@pytest.mark.parametrize(
    ("word", "n", "prefix"),
    [
        ("a", 1, 1),
        ("to", 2, 1),
        ("the", 3, 2),
        ("read", 4, 2),
        ("smooth", 6, 3),
        ("reading", 7, 4),
        ("2024", 4, 0),
        ("naïve", 5, 3),
    ],
)
def test_spec_table_strength_3(word: str, n: int, prefix: int) -> None:
    assert grapheme_count(word) == n
    assert fx(word) == prefix


@pytest.mark.parametrize(
    ("strength", "expected"),
    [(1, 1), (2, 2), (3, 3), (4, 4), (5, 5)],
)
def test_ratios_on_a_six_letter_word(strength: int, expected: int) -> None:
    # n=6: 1.2, 2.1, 3.0, 3.9, 4.8 -> floor(x + 0.5)
    assert fx("smooth", fixation=strength) == expected


@pytest.mark.parametrize(
    ("strength", "expected"),
    [(1, 1), (2, 2), (3, 4), (4, 5), (5, 6)],
)
def test_ratios_on_a_seven_letter_word(strength: int, expected: int) -> None:
    # n=7: 1.4, 2.45, 3.5, 4.55, 5.6
    assert fx("reading", fixation=strength) == expected


@pytest.mark.parametrize(("strength", "expected"), [(1, 0), (2, 0), (3, 1), (4, 1), (5, 1)])
def test_single_character_words_need_strength_3(strength: int, expected: int) -> None:
    assert fx("a", fixation=strength) == expected


def test_prefix_never_exceeds_the_word() -> None:
    assert fx("to", fixation=5) == 2
    assert fx("a", fixation=5) == 1


def test_numbers_are_skipped_by_default() -> None:
    assert fx("2024") == 0
    assert fx("2024", emphasize_numbers=True) == 2
    assert fx("٢٠٢٤") == 0  # Arabic-Indic digits are Nd too


def test_single_digit_is_not_emphasised_even_at_strength_5() -> None:
    # The special cases of spec section 2 are filters, not early returns.
    assert fx("5", fixation=5) == 0
    assert fx("5", fixation=5, emphasize_numbers=True) == 1


def test_alphanumeric_words_are_not_numbers() -> None:
    assert fx("h2o") == 2


def test_min_word_length() -> None:
    assert fx("the", min_word_length=4) == 0
    assert fx("read", min_word_length=4) == 2


def test_apostrophes_count_as_characters() -> None:
    assert grapheme_count("don't") == 5
    assert fx("don't") == 3


def test_combining_marks_do_not_split() -> None:
    decomposed = "naïve"
    assert len(decomposed) == 6
    assert grapheme_count(decomposed) == 5
    assert fx(decomposed) == 3


def test_override_replaces_the_algorithm() -> None:
    opts = Options(fixation_length=lambda word, n, o: n)
    assert fixation_length("2024", 4, opts) == 4
    assert fixation_length("a", 1, opts) == 1
    clamped = Options(fixation_length=lambda word, n, o: 99)
    assert fixation_length("the", 3, clamped) == 3


def test_invalid_options_are_rejected() -> None:
    with pytest.raises(ValueError):
        Options(fixation=6)
    with pytest.raises(ValueError):
        Options(saccade=0)
