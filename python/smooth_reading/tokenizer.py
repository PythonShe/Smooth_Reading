"""Unicode-aware word/separator scanner (spec section 3, fallback tokenizer).

Python's :mod:`re` has no ``\\p{...}`` property escapes and ``\\w`` wrongly
includes ``_``, so the spec regex ``[\\p{L}\\p{N}\\p{M}]+(?:['’][\\p{L}\\p{N}\\p{M}]+)*``
is implemented as a hand-written scanner over :func:`unicodedata.category`.
It produces exactly the tokens the regex would, with the additional rule that a
run of Han / Hiragana / Katakana / Hangul / Thai characters is a word of its own
(these scripts do not separate words with spaces).
"""

from __future__ import annotations

import unicodedata
from typing import Iterator

__all__ = ["APOSTROPHES", "is_word_char", "is_scriptio_continua", "iter_raw_tokens"]

#: Characters that join two word runs into a single word (spec section 3).
APOSTROPHES = frozenset("'’")

# Inclusive code-point ranges for the scripts written without spaces.
_CONTINUOUS_RANGES: tuple[tuple[int, int], ...] = (
    (0x0E00, 0x0E7F),  # Thai
    (0x1100, 0x11FF),  # Hangul Jamo
    (0x2E80, 0x2EFF),  # CJK Radicals Supplement
    (0x3005, 0x3007),  # ideographic iteration mark, ideographic numbers
    (0x3041, 0x309F),  # Hiragana
    (0x30A0, 0x30FF),  # Katakana
    (0x3130, 0x318F),  # Hangul Compatibility Jamo
    (0x31F0, 0x31FF),  # Katakana Phonetic Extensions
    (0x3400, 0x4DBF),  # CJK Extension A
    (0x4E00, 0x9FFF),  # CJK Unified Ideographs
    (0xA960, 0xA97F),  # Hangul Jamo Extended-A
    (0xAC00, 0xD7A3),  # Hangul Syllables
    (0xD7B0, 0xD7FF),  # Hangul Jamo Extended-B
    (0xF900, 0xFAFF),  # CJK Compatibility Ideographs
    (0xFF66, 0xFF9D),  # halfwidth Katakana
    (0xFFA0, 0xFFDC),  # halfwidth Hangul
    (0x20000, 0x2A6DF),
    (0x2A700, 0x2EBEF),
    (0x2F800, 0x2FA1F),
)


def is_word_char(char: str) -> bool:
    """True for ``\\p{L}``, ``\\p{N}`` and ``\\p{M}`` (letters, numbers, marks)."""
    return unicodedata.category(char)[0] in ("L", "N", "M")


def is_scriptio_continua(char: str) -> bool:
    """True for scripts written without spaces (Han, Kana, Hangul, Thai)."""
    code = ord(char)
    for low, high in _CONTINUOUS_RANGES:
        if code < low:
            return False
        if code <= high:
            return True
    return False


def iter_raw_tokens(text: str) -> Iterator[tuple[bool, str]]:
    """Yield ``(is_word, text)`` pairs covering ``text`` exactly, in order."""
    length = len(text)
    index = 0
    while index < length:
        char = text[index]
        if not is_word_char(char):
            start = index
            while index < length and not is_word_char(text[index]):
                index += 1
            yield False, text[start:index]
            continue

        start = index
        if is_scriptio_continua(char):
            # A run of space-less script is one word; combining marks (Thai) join it.
            while index < length and is_word_char(text[index]) and (
                is_scriptio_continua(text[index]) or unicodedata.category(text[index])[0] == "M"
            ):
                index += 1
            yield True, text[start:index]
            continue

        while True:
            while (
                index < length
                and is_word_char(text[index])
                and not is_scriptio_continua(text[index])
            ):
                index += 1
            # An apostrophe joins only when a word character follows it.
            if (
                index + 1 < length
                and text[index] in APOSTROPHES
                and is_word_char(text[index + 1])
                and not is_scriptio_continua(text[index + 1])
            ):
                index += 1
                continue
            break
        yield True, text[start:index]
