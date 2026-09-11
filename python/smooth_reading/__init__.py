"""smooth-reading -- guided fixation reading for Python.

Emphasises the leading grapheme clusters of every word so the eye gets an
artificial fixation point. Deterministic, language-agnostic and dependency-free;
the algorithm is defined by ``docs/SPEC.md`` in the project repository.
"""

from __future__ import annotations

from .core import Token, fixation_length, tokenize
from .html import SKIP_TAGS, to_html, to_markdown
from .options import DEFAULTS, Options

__all__ = [
    "DEFAULTS",
    "SKIP_TAGS",
    "Options",
    "Token",
    "fixation_length",
    "to_html",
    "to_markdown",
    "tokenize",
]

__version__ = "0.3.0"
