"""Run the shared cross-port fixtures (docs/SPEC.md section 7).

``fixtures/common/*.json`` is produced alongside the TypeScript core; every case
must render identically here. The whole module skips cleanly while that directory
does not exist yet.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from smooth_reading import to_html

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_DIR = REPO_ROOT / "fixtures" / "common"


def _load() -> list[tuple[str, dict[str, Any]]]:
    cases: list[tuple[str, dict[str, Any]]] = []
    if not FIXTURE_DIR.is_dir():
        return cases
    for path in sorted(FIXTURE_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            data = data.get("cases", [])
        for index, case in enumerate(data):
            name = str(case.get("name", index))
            cases.append((f"{path.stem}:{name}", case))
    return cases


CASES = _load()


def test_fixture_directory_is_present() -> None:
    if not FIXTURE_DIR.is_dir() or not any(FIXTURE_DIR.glob("*.json")):
        pytest.skip(f"{FIXTURE_DIR} has no fixtures yet")
    assert CASES, f"no fixture cases found in {FIXTURE_DIR}"


@pytest.mark.skipif(not CASES, reason="fixtures/common/*.json not available yet")
@pytest.mark.parametrize(
    ("name", "case"),
    CASES or [("none", {})],
    ids=[name for name, _ in CASES] or ["none"],
)
def test_common_fixture(name: str, case: dict[str, Any]) -> None:
    options = dict(case.get("options") or {})
    assert to_html(case["input"], tag="b", options=options) == case["html"]
