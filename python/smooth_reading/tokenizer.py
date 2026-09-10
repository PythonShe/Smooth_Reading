"""Word/separator scanner: the regex fallback tokenizer of docs/SPEC.md section 3.

Python's :mod:`re` has no ``\\p{...}`` property escapes (and ``\\w`` matches
``_``), so the spec regex ``[\\p{L}\\p{N}\\p{M}]+(?:['’][\\p{L}\\p{N}\\p{M}]+)*``
is implemented as a hand-written scanner over :func:`unicodedata.category`.
It yields exactly the tokens the regex would, plus the spec's extra rule that a
run of CJK characters (Han, Hiragana, Katakana, Hangul) is a word of its own.
"""

from __future__ import annotations

import unicodedata
from collections.abc import Iterator

#: Characters that join two word runs into one word (``don't``, ``it’s``).
_APOSTROPHES = frozenset("'’")

# Inclusive code-point ranges of the CJK scripts written without spaces, in
# ascending order (``is_cjk`` relies on it).
_CJK_RANGES: tuple[tuple[int, int], ...] = (
    (0x1100, 0x11FF),  # Hangul Jamo
    (0x3005, 0x3007),  # ideographic iteration mark, ideographic zero
    (0x3041, 0x30FF),  # Hiragana, Katakana
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
    (0x20000, 0x2EBEF),  # CJK Extensions B-F
    (0x2F800, 0x2FA1F),  # CJK Compatibility Ideographs Supplement
    (0x30000, 0x323AF),  # CJK Extensions G-H
)


def is_word_char(char: str) -> bool:
    """``\\p{L}``, ``\\p{N}`` or ``\\p{M}``: letters, numbers and marks."""
    return unicodedata.category(char)[0] in "LNM"


def is_cjk(char: str) -> bool:
    """True for Han, Hiragana, Katakana and Hangul word characters."""
    if not is_word_char(char):
        return False  # e.g. the Katakana middle dot U+30FB is punctuation
    code = ord(char)
    for low, high in _CJK_RANGES:
        if code < low:
            return False
        if code <= high:
            return True
    return False


def _is_mark(char: str) -> bool:
    return unicodedata.category(char)[0] == "M"


def iter_raw_tokens(text: str) -> Iterator[tuple[bool, str]]:
    """Yield ``(is_word, text)`` pairs that concatenate back to ``text``."""
    length = len(text)
    index = 0
    while index < length:
        start = index
        if not is_word_char(text[index]):
            # Separator: a maximal run of non-word characters.
            while index < length and not is_word_char(text[index]):
                index += 1
            yield False, text[start:index]
        elif is_cjk(text[index]):
            # CJK run: one word per run; combining marks stay attached.
            while index < length and (is_cjk(text[index]) or _is_mark(text[index])):
                index += 1
            yield True, text[start:index]
        else:
            # Ordinary word: word characters, optionally joined by apostrophes.
            # ``[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`` -- a CJK
            # character ends the run because it starts a word of its own.
            while True:
                while index < length and is_word_char(text[index]) and not is_cjk(text[index]):
                    index += 1
                joins = (
                    index + 1 < length
                    and text[index] in _APOSTROPHES
                    and is_word_char(text[index + 1])
                    and not is_cjk(text[index + 1])
                )
                if not joins:
                    break
                index += 1
            yield True, text[start:index]
