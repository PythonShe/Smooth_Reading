"""Approximate grapheme-cluster segmentation using only the standard library.

The spec (section 3) counts *user-perceived characters*. Full UAX #29 breaking
would need the third-party ``regex`` module or a bundled property table, so this
implements just the subset that matters inside word tokens:

* a base character followed by any combining marks (general category ``Mn``,
  ``Mc`` or ``Me``, which also covers variation selectors) is one cluster;
* a ZWJ (U+200D) joins the following character into the same cluster, so emoji
  ZWJ sequences count once;
* CR+LF is one cluster.

Known gaps versus UAX #29: regional-indicator pairs (flag emoji) count as two,
Hangul jamo sequences are not composed, and prepend characters and emoji
modifiers without ZWJ are not joined. None of these can occur inside a word
token produced by :mod:`smooth_reading.tokenizer`.
"""

from __future__ import annotations

import unicodedata
from collections.abc import Iterator

_ZWJ = "‍"
_MARK_CATEGORIES = frozenset({"Mn", "Mc", "Me"})


def iter_graphemes(text: str) -> Iterator[str]:
    """Yield the grapheme clusters of ``text`` in order."""
    length = len(text)
    start = 0
    while start < length:
        end = start + 1
        if text[start] == "\r" and text[end : end + 1] == "\n":
            end += 1
        while end < length:
            char = text[end]
            if unicodedata.category(char) in _MARK_CATEGORIES:
                end += 1
            elif char == _ZWJ:
                end = min(end + 2, length)  # the ZWJ and whatever it joins
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
