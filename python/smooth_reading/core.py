"""Fixation algorithm and tokenizer front end (spec sections 2-4)."""

from __future__ import annotations

import math
import unicodedata
from dataclasses import dataclass
from typing import Any, Iterator, Mapping, Optional

from .graphemes import grapheme_count, take_graphemes
from .options import DEFAULTS, Options, coerce_options
from .tokenizer import is_scriptio_continua, iter_raw_tokens

__all__ = ["Token", "round_half_up", "fixation_length", "tokenize", "DEFAULTS", "Options"]


def round_half_up(value: float) -> int:
    """``floor(x + 0.5)`` -- the rounding every port must use (spec section 2)."""
    return math.floor(value + 0.5)


def _is_all_digits(word: str) -> bool:
    return all(unicodedata.category(char) == "Nd" for char in word)


@dataclass(frozen=True)
class Token:
    """A piece of the input.

    ``type`` is ``"word"`` or ``"separator"``. Separators carry only ``text``;
    words additionally carry ``fixation`` (a grapheme-cluster count),
    ``fixation_text`` and ``rest_text`` where
    ``fixation_text + rest_text == text``.
    """

    type: str
    text: str
    fixation: int = 0
    fixation_text: str = ""
    rest_text: str = ""

    @property
    def is_word(self) -> bool:
        return self.type == "word"


def fixation_length(word: str, graphemes: int, options: Options) -> int:
    """How many leading grapheme clusters of ``word`` to emphasise.

    Applies the special cases of spec section 2 as successive filters, then the
    ratio formula. A user supplied ``options.fixation_length`` replaces the whole
    algorithm; its result is clamped to ``0..graphemes``.
    """
    if options.fixation_length is not None:
        return max(0, min(graphemes, int(options.fixation_length(word, graphemes, options))))

    if graphemes <= 0:
        return 0
    if not options.emphasize_numbers and _is_all_digits(word):
        return 0
    if graphemes < options.min_word_length:
        return 0

    if word and is_scriptio_continua(word[0]):
        # Spec section 3: a Han/Kana/Hangul/Thai run of k clusters is emphasised
        # on its first max(1, round_half_up(k * ratio)) clusters.
        return max(1, min(graphemes, round_half_up(graphemes * options.ratio)))

    if graphemes == 1:
        return 1 if options.fixation >= 3 else 0
    return max(1, min(graphemes, round_half_up(graphemes * options.ratio)))


def iter_tokens(
    text: str,
    options: Options,
    word_index: int = 0,
) -> Iterator[tuple[Token, int]]:
    """Yield ``(token, next_word_index)``; ``word_index`` seeds saccade counting."""
    for is_word, chunk in iter_raw_tokens(text):
        if not is_word:
            yield Token("separator", chunk), word_index
            continue
        count = grapheme_count(chunk)
        if word_index % options.saccade == 0:
            length = fixation_length(chunk, count, options)
        else:
            length = 0
        prefix, rest = take_graphemes(chunk, length)
        word_index += 1
        yield Token("word", chunk, length, prefix, rest), word_index


def tokenize(
    text: str,
    options: Optional[Options | Mapping[str, Any]] = None,
    **overrides: Any,
) -> list[Token]:
    """Split ``text`` into word and separator tokens with fixation splits.

    ``tokenize("Smooth reading")`` uses the defaults; options may be passed as an
    :class:`Options`, a mapping, or keyword arguments (``fixation=4``,
    ``min_word_length=3`` / ``minWordLength=3``).
    """
    opts = coerce_options(options, **overrides)
    return [token for token, _ in iter_tokens(text, opts)]
