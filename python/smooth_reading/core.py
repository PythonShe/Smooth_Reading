"""Fixation length algorithm and tokenizer (docs/SPEC.md sections 2-4)."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from typing import Any, Literal

from .graphemes import grapheme_count, split_graphemes
from .options import DEFAULTS, Options, resolve
from .tokenizer import iter_raw_tokens

_PERCENT = {1: 20, 2: 35, 3: 50, 4: 65, 5: 80}


def _round_half_up(graphemes: int, fixation: int) -> int:
    # Spec section 2: floor((n * percent + 50) / 100) == floor(n * ratio + 0.5),
    # never banker's rounding, so every port agrees.
    return (graphemes * _PERCENT[fixation] + 50) // 100


def _is_all_digits(word: str) -> bool:
    return all(unicodedata.category(char) == "Nd" for char in word)


@dataclass(frozen=True)
class Token:
    """A piece of the input: a word or a separator (whitespace, punctuation).

    Separators carry only ``text``. Words also carry ``fixation`` (the number
    of emphasised grapheme clusters, ``0`` when the word gets no fixation),
    ``fixation_text`` and ``rest_text``, where ``fixation_text + rest_text ==
    text``.
    """

    type: Literal["word", "separator"]
    text: str
    fixation: int = 0
    fixation_text: str = ""
    rest_text: str = ""


def fixation_length(word: str, graphemes: int, options: Options = DEFAULTS) -> int:
    """How many leading grapheme clusters of ``word`` (``graphemes`` long) to emphasise.

    Implements spec section 2 in order: suppression rules, the single-character
    rule, then the ratio formula. ``options.fixation_length`` replaces all of it.
    """
    if options.fixation_length is not None:
        return max(0, min(graphemes, options.fixation_length(word, graphemes, options)))
    if graphemes < 1:
        return 0
    # Rule 1: digit-only words are not emphasised unless asked for.
    if _is_all_digits(word) and not options.emphasize_numbers:
        return 0
    # Rule 2: words shorter than min_word_length are not emphasised.
    if graphemes < options.min_word_length:
        return 0
    # Rule 3: a single character is emphasised only at strength >= 3, in every
    # script (a one-character CJK word is not exempt).
    if graphemes == 1:
        return 1 if options.fixation >= 3 else 0
    # Rule 4: clamp(round_half_up(n * ratio), 1, n), in the integer form the
    # spec prescribes so no port drifts on floating point.
    return max(1, min(graphemes, _round_half_up(graphemes, options.fixation)))


def tokenize_from(text: str, options: Options, word_index: int) -> tuple[list[Token], int]:
    """Tokenize ``text`` continuing the saccade count at ``word_index``.

    Returns the tokens and the next word index, so callers that tokenize one
    text in several pieces (``to_html`` around markup) keep counting words.
    """
    tokens: list[Token] = []
    for is_word, chunk in iter_raw_tokens(text):
        if not is_word:
            tokens.append(Token("separator", chunk))
            continue
        # Spec section 4: saccade counts word tokens only, whether or not they
        # end up emphasised; index 0 (the first word) always gets a fixation.
        length = 0
        if word_index % options.saccade == 0:
            length = fixation_length(chunk, grapheme_count(chunk), options)
        prefix, rest = split_graphemes(chunk, length)
        tokens.append(Token("word", chunk, length, prefix, rest))
        word_index += 1
    return tokens, word_index


def tokenize(text: str, options: Options | None = None, **overrides: Any) -> list[Token]:
    """Split ``text`` into word and separator tokens with their fixation splits.

    Options are given as an :class:`Options` instance and/or keyword arguments
    (``tokenize(text, fixation=4, saccade=2)``).
    """
    tokens, _ = tokenize_from(text, resolve(options, overrides), 0)
    return tokens
