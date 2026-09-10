"""Multilingual and bidi guarantees over every fixture input (docs/LANGUAGES.md).

The ``segmenter`` fixtures are not expected to *match* in the regex port, but
their inputs are still valid text, so the invariants below must hold for them
too: tokens are lossless, the markup adds nothing but emphasis tags, and no
direction-changing attribute or bidi control character is ever introduced.
"""

from __future__ import annotations

import html
import json
import re
from pathlib import Path
from typing import Any

import pytest

from smooth_reading import Options, to_html, tokenize

FIXTURE_ROOT = Path(__file__).resolve().parents[2] / "fixtures"

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

# LRM, RLM, ALM, the explicit embeddings/overrides and the isolates.
_BIDI_CONTROLS = re.compile("[\u200e\u200f\u061c\u202a-\u202e\u2066-\u2069]")


def _load() -> list[tuple[str, dict[str, Any]]]:
    cases = []
    for suite in ("common", "segmenter"):
        for path in sorted((FIXTURE_ROOT / suite).glob("*.json")):
            for case in json.loads(path.read_text(encoding="utf-8")):
                cases.append((f"{suite}/{path.stem}: {case['name']}", case))
    return cases


CASES = _load()


def _split_options(case: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    algorithm: dict[str, Any] = {}
    markup: dict[str, Any] = {}
    for key, value in case.get("options", {}).items():
        if key in _ALGORITHM_OPTIONS:
            algorithm[_ALGORITHM_OPTIONS[key]] = value
        else:
            markup[_HTML_OPTIONS[key]] = value
    return algorithm, markup


def _escape(text: str) -> str:
    return html.escape(text, quote=False).replace('"', "&quot;")


def _strip_emphasis(markup: str, tags: list[str]) -> str:
    names = "|".join(re.escape(tag) for tag in tags)
    return re.sub(rf"</?(?:{names})(?:\s[^>]*)?>", "", markup)


def test_scripts_fixture_file_is_present() -> None:
    assert any(name.startswith("common/scripts:") for name, _ in CASES)


@pytest.mark.parametrize(("name", "case"), CASES, ids=[name for name, _ in CASES])
def test_tokens_are_lossless(name: str, case: dict[str, Any]) -> None:
    algorithm, _ = _split_options(case)
    tokens = tokenize(case["input"], Options(**algorithm))
    assert "".join(token.text for token in tokens) == case["input"]
    for token in tokens:
        if token.type == "word":
            assert token.fixation_text + token.rest_text == token.text


@pytest.mark.parametrize(("name", "case"), CASES, ids=[name for name, _ in CASES])
def test_markup_adds_nothing_but_emphasis_tags(name: str, case: dict[str, Any]) -> None:
    algorithm, markup = _split_options(case)
    text = case["input"]
    rendered = to_html(text, Options(**algorithm), **markup)
    # The same render with every fixation suppressed adds no emphasis tags of
    # its own (the input may already contain some, hence stripping both sides).
    plain = to_html(text, Options(**algorithm, fixation_length=lambda _w, _n, _o: 0), **markup)
    emphasis = [markup.get("tag", "b")]
    if markup.get("rest_tag"):
        emphasis.append(markup["rest_tag"])
    assert _strip_emphasis(rendered, emphasis) == _strip_emphasis(plain, emphasis)
    if not markup.get("ignore_html_tags", True) or not any(c in text for c in "<&"):
        assert plain == _escape(text)


@pytest.mark.parametrize(("name", "case"), CASES, ids=[name for name, _ in CASES])
def test_no_dir_attribute_or_bidi_control_is_added(name: str, case: dict[str, Any]) -> None:
    algorithm, markup = _split_options(case)
    text = case["input"]
    rendered = to_html(text, Options(**algorithm), **markup)
    assert rendered.count("dir=") == text.count("dir=")
    assert len(_BIDI_CONTROLS.findall(rendered)) == len(_BIDI_CONTROLS.findall(text))


def test_decomposed_hangul_jamo_compose() -> None:
    import unicodedata

    decomposed = unicodedata.normalize("NFD", "한글")
    [word] = tokenize(decomposed, fixation=1)
    assert word.fixation_text == unicodedata.normalize("NFD", "한")


def test_indic_conjuncts_are_one_cluster() -> None:
    [word] = tokenize("क्षत्रिय")
    assert (word.fixation_text, word.rest_text) == ("क्षत्रि", "य")
    [word] = tokenize("ক্ষমা")  # Bengali
    assert word.fixation_text == "ক্ষ"
    [word] = tokenize("தமிழ்")  # Tamil pulli is not a linker
    assert word.fixation_text == "தமி"
    [word] = tokenize("उम्र")  # an independent vowel does not link
    assert (word.fixation_text, word.rest_text) == ("उ", "म्र")
