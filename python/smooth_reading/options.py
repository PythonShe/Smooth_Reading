"""Algorithm options (``SmoothOptions`` in docs/SPEC.md section 4)."""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass, replace
from typing import Any

#: Fixation strength -> ratio of the word that is emphasised (spec section 2).
_RATIOS: dict[int, float] = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}


def _is_number(value: object) -> bool:
    # ``bool`` is a subclass of ``int``; ``saccade=True`` is a bug, not a 1.
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _truncate(value: object, non_finite: int) -> int | None:
    """Truncate a number toward zero, like TypeScript's ``Math.trunc``.

    Returns ``None`` for anything that is not a number (or is a ``bool``), so the
    caller can raise; ``fixation=4.9`` is a ``4`` to be clamped, not an error, and
    a non-finite value falls back to ``non_finite`` exactly as in the core.
    """
    if not _is_number(value):
        return None
    number = float(value)  # type: ignore[arg-type]
    return non_finite if not math.isfinite(number) else math.trunc(number)


@dataclass(frozen=True)
class Options:
    """Algorithm options with the spec defaults.

    ``fixation_length`` replaces the whole fixation algorithm: it receives the
    word, its grapheme-cluster count and the resolved options, and returns how
    many leading grapheme clusters to emphasise (clamped to ``0..count``).
    """

    fixation: int = 3
    saccade: int = 1
    min_word_length: int = 1
    emphasize_numbers: bool = False
    locale: str | None = None
    fixation_length: Callable[[str, int, Options], int] | None = None

    def __post_init__(self) -> None:
        # Wrong types are rejected; numbers are truncated toward zero (like the
        # core's ``Math.trunc``) and then clamped into range (spec section 4),
        # so ``fixation=4.9`` is a 4 and ``min_word_length=-1`` behaves like 0.
        fixation = _truncate(self.fixation, 3)
        if fixation is None:
            raise ValueError(f"fixation must be an integer from 1 to 5, got {self.fixation!r}")
        saccade = _truncate(self.saccade, 1)
        if saccade is None:
            raise ValueError(f"saccade must be an integer >= 1, got {self.saccade!r}")
        min_word_length = _truncate(self.min_word_length, 0)
        if min_word_length is None:
            raise ValueError(
                f"min_word_length must be an integer >= 0, got {self.min_word_length!r}"
            )
        object.__setattr__(self, "fixation", min(max(fixation, 1), 5))
        object.__setattr__(self, "saccade", max(saccade, 1))
        object.__setattr__(self, "min_word_length", max(min_word_length, 0))
        if self.fixation_length is not None and not callable(self.fixation_length):
            raise ValueError(
                f"fixation_length must be callable or None, got {self.fixation_length!r}"
            )

    @property
    def ratio(self) -> float:
        """Fraction of each word that is emphasised at this ``fixation`` strength."""
        return _RATIOS[self.fixation]


#: The spec defaults (``defaults`` in the TypeScript core).
DEFAULTS = Options()


def resolve(options: Options | None, overrides: dict[str, Any]) -> Options:
    """Combine an optional :class:`Options` with keyword overrides.

    Unknown override names raise ``TypeError`` (from ``dataclasses.replace``) and
    invalid values raise ``ValueError`` (from :meth:`Options.__post_init__`).
    """
    base = DEFAULTS if options is None else options
    return replace(base, **overrides) if overrides else base
