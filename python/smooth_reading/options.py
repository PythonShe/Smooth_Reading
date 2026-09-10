"""Options for the smooth-reading algorithm."""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any, Callable, Mapping, Optional

__all__ = ["Options", "DEFAULTS", "FixationLengthFn", "coerce_options"]

#: Signature of a user supplied override for the fixation-length algorithm.
#: It receives the word, its grapheme-cluster count and the resolved options,
#: and returns how many *grapheme clusters* to emphasise.
FixationLengthFn = Callable[[str, int, "Options"], int]

#: Fixation strength -> ratio of the word that is emphasised (spec section 2).
RATIOS: dict[int, float] = {1: 0.20, 2: 0.35, 3: 0.50, 4: 0.65, 5: 0.80}


@dataclass(frozen=True)
class Options:
    """Resolved options. All fields have the spec defaults."""

    fixation: int = 3
    saccade: int = 1
    min_word_length: int = 1
    emphasize_numbers: bool = False
    locale: Optional[str] = None
    fixation_length: Optional[FixationLengthFn] = None

    def __post_init__(self) -> None:
        if self.fixation not in RATIOS:
            raise ValueError(f"fixation must be one of {sorted(RATIOS)}, got {self.fixation!r}")
        if not isinstance(self.saccade, int) or isinstance(self.saccade, bool) or self.saccade < 1:
            raise ValueError(f"saccade must be an integer >= 1, got {self.saccade!r}")
        if (
            not isinstance(self.min_word_length, int)
            or isinstance(self.min_word_length, bool)
            or self.min_word_length < 0
        ):
            raise ValueError(
                f"min_word_length must be an integer >= 0, got {self.min_word_length!r}"
            )

    @property
    def ratio(self) -> float:
        return RATIOS[self.fixation]

    def replace(self, **changes: Any) -> "Options":
        """Return a copy with ``changes`` applied (snake_case or camelCase keys)."""
        return replace(self, **_normalise_keys(changes))


#: The spec defaults (``defaults`` in the TypeScript core).
DEFAULTS = Options()


# camelCase spellings from the shared spec / JSON fixtures -> Python field names.
_ALIASES: dict[str, str] = {
    "fixation": "fixation",
    "saccade": "saccade",
    "minwordlength": "min_word_length",
    "min_word_length": "min_word_length",
    "emphasizenumbers": "emphasize_numbers",
    "emphasise_numbers": "emphasize_numbers",
    "emphasisenumbers": "emphasize_numbers",
    "emphasize_numbers": "emphasize_numbers",
    "locale": "locale",
    "fixationlength": "fixation_length",
    "fixation_length": "fixation_length",
}


def _normalise_keys(mapping: Mapping[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in mapping.items():
        field = _ALIASES.get(key.lower().replace("_", "").replace("-", "")) or _ALIASES.get(
            key.lower()
        )
        if field is None:
            raise TypeError(f"unknown option {key!r}")
        out[field] = value
    return out


def coerce_options(
    options: Optional[Options | Mapping[str, Any]] = None, **overrides: Any
) -> Options:
    """Build an :class:`Options` from an instance / mapping plus keyword overrides.

    Both ``min_word_length`` and the fixture spelling ``minWordLength`` are accepted.
    """
    base = DEFAULTS
    if isinstance(options, Options):
        base = options
    elif options is not None:
        base = replace(DEFAULTS, **_normalise_keys(options))
    if overrides:
        base = replace(base, **_normalise_keys(overrides))
    return base
