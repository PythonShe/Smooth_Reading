"""Hand-derived cases from docs/SPEC.md section 2."""

from __future__ import annotations

from typing import Any

import pytest

from smooth_reading import Options, fixation_length
from smooth_reading.core import _round_half_up
from smooth_reading.graphemes import grapheme_count


def fx(word: str, **options: Any) -> int:
    return fixation_length(word, grapheme_count(word), Options(**options))


@pytest.mark.parametrize(
    ("graphemes", "fixation", "expected"),
    # 2.5 -> 3 (not banker's 2), 3.5 -> 4, 0.7 -> 1, 1.4 -> 1, 4.55 -> 5
    [(5, 3, 3), (7, 3, 4), (2, 2, 1), (4, 2, 1), (7, 4, 5), (1, 1, 0)],
)
def test_round_half_up_is_not_bankers(graphemes: int, fixation: int, expected: int) -> None:
    assert _round_half_up(graphemes, fixation) == expected


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


@pytest.mark.parametrize(("strength", "expected"), [(1, 1), (2, 2), (3, 3), (4, 4), (5, 5)])
def test_ratios_on_a_six_letter_word(strength: int, expected: int) -> None:
    # n=6: 1.2, 2.1, 3.0, 3.9, 4.8 -> floor(x + 0.5)
    assert fx("smooth", fixation=strength) == expected


@pytest.mark.parametrize(("strength", "expected"), [(1, 1), (2, 2), (3, 4), (4, 5), (5, 6)])
def test_ratios_on_a_seven_letter_word(strength: int, expected: int) -> None:
    # n=7: 1.4, 2.45, 3.5, 4.55, 5.6
    assert fx("reading", fixation=strength) == expected


@pytest.mark.parametrize(("strength", "expected"), [(1, 0), (2, 0), (3, 1), (4, 1), (5, 1)])
def test_single_character_words_need_strength_3(strength: int, expected: int) -> None:
    assert fx("a", fixation=strength) == expected


def test_prefix_is_at_least_one_and_at_most_the_word() -> None:
    assert fx("to", fixation=1) == 1  # 0.4 rounds to 0, clamped up
    assert fx("to", fixation=5) == 2  # 1.6 rounds to 2 == n


def test_numbers_are_skipped_by_default() -> None:
    assert fx("2024") == 0
    assert fx("2024", emphasize_numbers=True) == 2
    assert fx("٢٠٢٤") == 0  # Arabic-Indic digits are Nd too


def test_suppression_wins_over_the_single_character_rule() -> None:
    # Spec section 2: suppression rules are evaluated before rule 3.
    assert fx("5", fixation=5) == 0
    assert fx("5", fixation=5, emphasize_numbers=True) == 1
    assert fx("a", fixation=5, min_word_length=2) == 0


def test_alphanumeric_words_are_not_numbers() -> None:
    assert fx("h2o") == 2


def test_min_word_length() -> None:
    assert fx("the", min_word_length=4) == 0
    assert fx("read", min_word_length=4) == 2
    assert fx("read", min_word_length=0) == 2


def test_apostrophes_count_as_characters() -> None:
    assert grapheme_count("don't") == 5
    assert fx("don't") == 3


def test_combining_marks_do_not_split() -> None:
    decomposed = "naïve"
    assert len(decomposed) == 6
    assert grapheme_count(decomposed) == 5
    assert fx(decomposed) == 3


def test_empty_word_gets_no_fixation() -> None:
    assert fixation_length("", 0) == 0


def test_override_replaces_the_algorithm() -> None:
    whole = Options(fixation_length=lambda word, n, o: n)
    assert fixation_length("2024", 4, whole) == 4  # numbers are no longer suppressed
    assert fixation_length("a", 1, whole) == 1


def test_override_result_is_clamped_to_the_word() -> None:
    assert fixation_length("the", 3, Options(fixation_length=lambda w, n, o: 99)) == 3
    assert fixation_length("the", 3, Options(fixation_length=lambda w, n, o: -1)) == 0


def test_override_receives_the_resolved_options() -> None:
    seen: list[tuple[str, int, Options]] = []

    def record(word: str, n: int, options: Options) -> int:
        seen.append((word, n, options))
        return 1

    options = Options(fixation=5, fixation_length=record)
    fixation_length("word", 4, options)
    assert seen == [("word", 4, options)]
    assert seen[0][2].ratio == 0.80


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("fixation", 3.0, "fixation must be an integer from 1 to 5, got 3.0"),
        ("fixation", True, "fixation must be an integer from 1 to 5, got True"),
        ("saccade", "2", "saccade must be an integer >= 1, got '2'"),
        ("min_word_length", -1, "min_word_length must be an integer >= 0, got -1"),
        ("fixation_length", 3, "fixation_length must be callable or None, got 3"),
    ],
)
def test_invalid_options_are_rejected_with_a_clear_message(
    field: str, value: Any, message: str
) -> None:
    with pytest.raises(ValueError, match=message):
        Options(**{field: value})


@pytest.mark.parametrize(
    ("field", "value", "expected"),
    [
        ("fixation", 0, 1),
        ("fixation", -3, 1),
        ("fixation", 6, 5),
        ("fixation", 99, 5),
        ("saccade", 0, 1),
        ("saccade", -1, 1),
    ],
)
def test_out_of_range_options_are_clamped_not_rejected(
    field: str, value: int, expected: int
) -> None:
    # Spec section 4: every port clamps, none throws or silently substitutes the default.
    assert getattr(Options(**{field: value}), field) == expected


def test_clamped_fixation_drives_the_algorithm() -> None:
    assert fixation_length("reading", 7, Options(fixation=9)) == fixation_length(
        "reading", 7, Options(fixation=5)
    )
    assert fixation_length("reading", 7, Options(fixation=0)) == fixation_length(
        "reading", 7, Options(fixation=1)
    )


def test_defaults_match_the_spec() -> None:
    assert Options() == Options(
        fixation=3, saccade=1, min_word_length=1, emphasize_numbers=False, locale=None
    )
    assert Options().ratio == 0.50
