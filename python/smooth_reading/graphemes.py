"""Approximate grapheme-cluster segmentation using only the standard library.

The spec (section 3) counts *user-perceived characters*. Full UAX #29 breaking
would need the third-party ``regex`` module or a bundled property table, so this
implements just the subset that matters inside word tokens:

* a base character followed by any combining marks (general category ``Mn``,
  ``Mc`` or ``Me``, which also covers variation selectors) is one cluster;
* a ZWJ (U+200D) joins the following character into the same cluster, so emoji
  ZWJ sequences count once;
* Hangul jamo sequences compose (UAX #29 GB6-GB8): a leading consonant, a vowel
  and a trailing consonant written as separate jamo are one syllable, so a
  decomposed (NFD) Korean word counts the same as a precomposed one;
* Indic conjuncts link (UAX #29 GB9c, Unicode 15.1): a consonant, a virama and
  the next consonant of the Devanagari, Bengali, Gujarati, Oriya, Telugu and
  Malayalam scripts stay in one cluster, so ``क्ष`` is never split between the
  emphasised and the plain part of a word;
* CR+LF is one cluster.

Known gaps versus UAX #29: regional-indicator pairs (flag emoji) count as two,
and prepend characters and emoji modifiers without ZWJ are not joined. Neither
can occur inside a word token produced by :mod:`smooth_reading.tokenizer`.
Conjunct linking for scripts that Unicode 17 added to the rule (Khmer coeng,
Myanmar virama, Tai Tham, Balinese, Sundanese) is deliberately not applied:
current ICU builds disagree with each other about them, and the fixtures avoid
such sequences (see ``docs/LANGUAGES.md``).
"""

from __future__ import annotations

import unicodedata
from collections.abc import Iterator

_ZWJ = "\u200d"
_MARK_CATEGORIES = frozenset({"Mn", "Mc", "Me"})

# Hangul jamo classes (Hangul_Syllable_Type). LV/LVT precomposed syllables are
# told apart arithmetically: every 28th code point from U+AC00 is an LV syllable.
_JAMO_L = ((0x1100, 0x115F), (0xA960, 0xA97C))
_JAMO_V = ((0x1160, 0x11A7), (0xD7B0, 0xD7C6))
_JAMO_T = ((0x11A8, 0x11FF), (0xD7CB, 0xD7FB))
_SYLLABLE_FIRST, _SYLLABLE_LAST = 0xAC00, 0xD7A3

# UAX #29 GB9c (Unicode 15.1): Indic_Conjunct_Break=Linker viramas and the
# consonants of the same six scripts (Indic_Conjunct_Break=Consonant).
_INDIC_LINKERS = frozenset({0x094D, 0x09CD, 0x0ACD, 0x0B4D, 0x0C4D, 0x0D4D})
_INDIC_CONSONANTS: tuple[tuple[int, int], ...] = (
    (0x0915, 0x0939),
    (0x0958, 0x095F),
    (0x0978, 0x097F),  # Devanagari
    (0x0995, 0x09A8),
    (0x09AA, 0x09B0),
    (0x09B2, 0x09B2),
    (0x09B6, 0x09B9),  # Bengali
    (0x09DC, 0x09DD),
    (0x09DF, 0x09DF),
    (0x09F0, 0x09F1),
    (0x0A95, 0x0AA8),
    (0x0AAA, 0x0AB0),
    (0x0AB2, 0x0AB3),
    (0x0AB5, 0x0AB9),  # Gujarati
    (0x0AF9, 0x0AF9),
    (0x0B15, 0x0B28),
    (0x0B2A, 0x0B30),
    (0x0B32, 0x0B33),
    (0x0B35, 0x0B39),  # Oriya
    (0x0B5C, 0x0B5D),
    (0x0B5F, 0x0B5F),
    (0x0B71, 0x0B71),
    (0x0C15, 0x0C28),
    (0x0C2A, 0x0C39),
    (0x0C58, 0x0C5A),  # Telugu
    (0x0D15, 0x0D3A),  # Malayalam
)


def _in_ranges(code: int, ranges: tuple[tuple[int, int], ...]) -> bool:
    return any(low <= code <= high for low, high in ranges)


def _jamo_class(char: str) -> str | None:
    """``"L"``, ``"V"``, ``"T"``, ``"LV"``, ``"LVT"`` or ``None``."""
    code = ord(char)
    if _SYLLABLE_FIRST <= code <= _SYLLABLE_LAST:
        return "LV" if (code - _SYLLABLE_FIRST) % 28 == 0 else "LVT"
    if _in_ranges(code, _JAMO_L):
        return "L"
    if _in_ranges(code, _JAMO_V):
        return "V"
    if _in_ranges(code, _JAMO_T):
        return "T"
    return None


def _hangul_joins(previous: str | None, following: str | None) -> bool:
    """GB6-GB8: whether two adjacent jamo classes stay in one syllable."""
    if previous is None or following is None:
        return False
    if previous == "L":
        return True  # L x (L | V | LV | LVT)
    if previous in ("LV", "V"):
        return following in ("V", "T")
    return following == "T"  # (LVT | T) x T


def _is_indic_consonant(char: str) -> bool:
    return _in_ranges(ord(char), _INDIC_CONSONANTS)


def iter_graphemes(text: str) -> Iterator[str]:
    """Yield the grapheme clusters of ``text`` in order."""
    length = len(text)
    start = 0
    while start < length:
        end = start + 1
        if text[start] == "\r" and text[end : end + 1] == "\n":
            end += 1
        # GB9c state: the cluster ends in a consonant followed by a linker
        # (with only marks in between), so a following consonant joins.
        saw_consonant = _is_indic_consonant(text[start])
        linked = False
        while end < length:
            char = text[end]
            category = unicodedata.category(char)
            if category in _MARK_CATEGORIES:
                if saw_consonant and ord(char) in _INDIC_LINKERS:
                    linked = True
                end += 1
            elif char == _ZWJ:
                end = min(end + 2, length)  # the ZWJ and whatever it joins
            elif _hangul_joins(_jamo_class(text[end - 1]), _jamo_class(char)):
                end += 1
            elif linked and _is_indic_consonant(char):
                linked = False
                end += 1
            else:
                break
        yield text[start:end]
        start = end


def grapheme_count(text: str) -> int:
    """Number of user-perceived characters in ``text``."""
    return sum(1 for _ in iter_graphemes(text))


def split_graphemes(text: str, count: int) -> tuple[str, str]:
    """Split ``text`` after ``count`` grapheme clusters into ``(prefix, rest)``."""
    index = 0
    for cluster in iter_graphemes(text):
        if count <= 0:
            break
        index += len(cluster)
        count -= 1
    return text[:index], text[index:]
