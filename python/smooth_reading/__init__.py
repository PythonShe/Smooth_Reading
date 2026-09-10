"""smooth-reading -- guided fixation reading for Python.

Emphasises the leading grapheme clusters of every word so the eye gets an
artificial fixation point. Deterministic, language-agnostic and dependency-free;
the algorithm is defined by ``docs/SPEC.md`` in the project repository.
"""

from __future__ import annotations

from .core import Token, fixation_length, round_half_up, tokenize
from .graphemes import grapheme_count, graphemes
from .html import SKIP_TAGS, escape, to_html, to_markdown
from .options import DEFAULTS, FixationLengthFn, Options, coerce_options

__all__ = [
    "DEFAULTS",
    "FixationLengthFn",
    "Options",
    "SKIP_TAGS",
    "Token",
    "coerce_options",
    "escape",
    "fixation_length",
    "grapheme_count",
    "graphemes",
    "round_half_up",
    "to_html",
    "to_markdown",
    "tokenize",
]

__version__ = "0.1.0"
