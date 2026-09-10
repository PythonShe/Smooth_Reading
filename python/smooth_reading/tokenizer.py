"""Word/separator scanner: the regex fallback tokenizer of docs/SPEC.md section 3.

Python's :mod:`re` has no ``\\p{...}`` property escapes (and ``\\w`` matches
``_``), so the spec regex ``[\\p{L}\\p{N}][\\p{L}\\p{N}\\p{M}]*(?:['’][\\p{L}\\p{N}\\p{M}]+)*``
is implemented as a hand-written scanner over :func:`unicodedata.category`.
It yields exactly the tokens the regex would, plus the spec's extra rule that a
continuous run of no-space-script characters (Han, Hiragana, Katakana, Hangul,
Thai, Lao, Myanmar, Khmer) is a word of its own.
"""

from __future__ import annotations

import unicodedata
from collections.abc import Iterator

#: Characters that join two word runs into one word (``don't``, ``it’s``).
_APOSTROPHES = frozenset("'’")

# Inclusive code-point ranges of the scripts written without spaces, in
# ascending order (``is_cjk`` relies on it). Mirrors the no-space-script table
# of docs/SPEC.md section 3 and ``RUN_RANGES`` in the TypeScript core.
_CJK_RANGES: tuple[tuple[int, int], ...] = (
    (0x0E00, 0x0E7F),  # Thai
    (0x0E80, 0x0EFF),  # Lao
    (0x1000, 0x109F),  # Myanmar
    (0x1100, 0x11FF),  # Hangul Jamo
    (0x1780, 0x17FF),  # Khmer
    (0x3005, 0x3007),  # ideographic iteration mark, ideographic zero
    (0x3041, 0x30FF),  # Hiragana, Katakana
    (0x3130, 0x318F),  # Hangul Compatibility Jamo
    (0x31F0, 0x31FF),  # Katakana Phonetic Extensions
    (0x3400, 0x4DBF),  # CJK Extension A
    (0x4E00, 0x9FFF),  # CJK Unified Ideographs
    (0xA960, 0xA97F),  # Hangul Jamo Extended-A
    (0xA9E0, 0xA9FF),  # Myanmar Extended-B
    (0xAA60, 0xAA7F),  # Myanmar Extended-A
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
    """True for a no-space-script word character (Han, Kana, Hangul, Thai, …)."""
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


def _starts_word(char: str) -> bool:
    """A word begins with a letter or number, never with a combining mark."""
    return unicodedata.category(char)[0] in "LN"


def iter_raw_tokens(text: str) -> Iterator[tuple[bool, str]]:
    """Yield ``(is_word, text)`` pairs that concatenate back to ``text``."""
    length = len(text)
    index = 0
    while index < length:
        start = index
        if not _starts_word(text[index]):
            # Separator: a maximal run of non-word characters. A combining
            # mark that does not follow a word character -- the variation
            # selector of an emoji such as ❤️, say -- belongs to the separator
            # it follows, exactly as in ICU (UAX #29 WB4); a word never starts
            # with a mark.
            while index < length and not _starts_word(text[index]):
                index += 1
            yield False, text[start:index]
        elif is_cjk(text[index]):
            # No-space-script run: one word per continuous run, split from the
            # letters and digits of other scripts (``iPhone手机`` is two words);
            # combining marks following a run character stay attached.
            while index < length and (is_cjk(text[index]) or _is_mark(text[index])):
                index += 1
            yield True, text[start:index]
        else:
            # Ordinary word: word characters, optionally joined by apostrophes.
            # ``[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*`` restricted to
            # non-run characters: a no-space-script character ends the word
            # because it starts a run of its own, and an apostrophe joins only
            # when the next character is a non-run word character.
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
