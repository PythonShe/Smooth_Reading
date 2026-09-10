"""Approximate grapheme-cluster segmentation using only the standard library.

Full UAX #29 grapheme cluster breaking is *not* implemented (that would need the
``regex`` module or a bundled break-property table). What is implemented is the
subset the fixation algorithm actually depends on:

* a base character plus any following combining marks (Unicode general category
  ``Mn``, ``Mc`` or ``Me``, which also covers variation selectors) is one cluster;
* a ZWJ (U+200D) always joins the following character into the same cluster,
  so emoji ZWJ sequences count as one cluster;
* a CR+LF pair is one cluster.

Known limitations versus UAX #29: regional-indicator pairs (flag emoji) count as
two clusters, Hangul jamo sequences are not composed, and prepend characters and
emoji modifier bases without ZWJ are not joined. None of these appear inside word
tokens produced by :mod:`smooth_reading.tokenizer`, and the shared ``common``
fixtures deliberately avoid emoji (spec section 3).
"""

from __future__ import annotations

import unicodedata
from typing import Iterator

__all__ = ["iter_graphemes", "graphemes", "grapheme_count", "take_graphemes"]

_ZWJ = "‍"
_MARKS = frozenset(("Mn", "Mc", "Me"))


def _is_mark(char: str) -> bool:
    return unicodedata.category(char) in _MARKS


def iter_graphemes(text: str) -> Iterator[str]:
    """Yield the grapheme clusters of ``text`` in order."""
    length = len(text)
    index = 0
    while index < length:
        end = index + 1
        if text[index] == "\r" and end < length and text[end] == "\n":
            end += 1
        while end < length:
            char = text[end]
            if _is_mark(char):
                end += 1
            elif char == _ZWJ:
                end += 1
                if end < length:
                    end += 1
            else:
                break
        yield text[index:end]
        index = end


def graphemes(text: str) -> list[str]:
    """Return the grapheme clusters of ``text`` as a list."""
    return list(iter_graphemes(text))


def grapheme_count(text: str) -> int:
    """Return the number of user-perceived characters in ``text``."""
    return sum(1 for _ in iter_graphemes(text))


def take_graphemes(text: str, count: int) -> tuple[str, str]:
    """Split ``text`` after ``count`` grapheme clusters into ``(prefix, rest)``."""
    if count <= 0:
        return "", text
    taken = 0
    index = 0
    for cluster in iter_graphemes(text):
        if taken == count:
            break
        index += len(cluster)
        taken += 1
    return text[:index], text[index:]
