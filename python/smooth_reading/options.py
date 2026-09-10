"""Algorithm options (``SmoothOptions`` in docs/SPEC.md section 4)."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from typing import Any

#: Fixation strength -> ratio of the word that is emphasised (spec section 2).
_RATIOS: dict[int, float] = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}


def _is_int(value: object) -> bool:
    # ``bool`` is a subclass of ``int``; ``saccade=True`` is a bug, not a 1.
    return isinstance(value, int) and not isinstance(value, bool)


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
        # Wrong types are rejected; out-of-range values are clamped into range
        # (spec section 4), matching every other port.
        if not _is_int(self.fixation):
            raise ValueError(f"fixation must be an integer from 1 to 5, got {self.fixation!r}")
        if not _is_int(self.saccade):
            raise ValueError(f"saccade must be an integer >= 1, got {self.saccade!r}")
        object.__setattr__(self, "fixation", min(max(self.fixation, 1), 5))
        object.__setattr__(self, "saccade", max(self.saccade, 1))
        if not _is_int(self.min_word_length) or self.min_word_length < 0:
            raise ValueError(
                f"min_word_length must be an integer >= 0, got {self.min_word_length!r}"
            )
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
