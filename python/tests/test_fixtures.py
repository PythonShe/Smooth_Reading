"""Run the shared cross-port fixtures (docs/SPEC.md section 7).

Every case in ``fixtures/common/*.json`` must render identically in every port.
Fixture options use the spec's camelCase names; algorithm options map onto
:class:`Options` fields and HTML options onto ``to_html`` keyword arguments.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from smooth_reading import Options, to_html

FIXTURE_DIR = Path(__file__).resolve().parents[2] / "fixtures" / "common"
FIXTURE_FILES = sorted(FIXTURE_DIR.glob("*.json"))

_ALGORITHM_OPTIONS = {
    "fixation": "fixation",
    "saccade": "saccade",
    "minWordLength": "min_word_length",
    "emphasizeNumbers": "emphasize_numbers",
    "locale": "locale",
}
_HTML_OPTIONS = {
    "tag": "tag",
    "className": "class_name",
    "restTag": "rest_tag",
    "restClassName": "rest_class_name",
    "ignoreHtmlTags": "ignore_html_tags",
    "skipTags": "skip_tags",
}


def _load_cases() -> list[tuple[str, dict[str, Any]]]:
    cases: list[tuple[str, dict[str, Any]]] = []
    for path in FIXTURE_FILES:
        for case in json.loads(path.read_text(encoding="utf-8")):
            cases.append((f"{path.stem}: {case['name']}", case))
    return cases


CASES = _load_cases()


def test_every_common_fixture_file_is_exercised() -> None:
    assert FIXTURE_FILES, f"no fixture files in {FIXTURE_DIR}"
    exercised = {name.split(":")[0] for name, _ in CASES}
    assert exercised == {path.stem for path in FIXTURE_FILES}


@pytest.mark.parametrize(("name", "case"), CASES, ids=[name for name, _ in CASES])
def test_common_fixture(name: str, case: dict[str, Any]) -> None:
    algorithm: dict[str, Any] = {}
    html: dict[str, Any] = {}
    for key, value in case.get("options", {}).items():
        if key in _ALGORITHM_OPTIONS:
            algorithm[_ALGORITHM_OPTIONS[key]] = value
        elif key in _HTML_OPTIONS:
            html[_HTML_OPTIONS[key]] = value
        else:
            pytest.fail(f"{name}: unknown fixture option {key!r}")
    assert to_html(case["input"], Options(**algorithm), **html) == case["html"]
