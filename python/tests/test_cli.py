"""CLI behaviour."""

from __future__ import annotations

import io
from pathlib import Path

import pytest

from smooth_reading.cli import main


def run(argv: list[str], stdin: str, capsys: pytest.CaptureFixture[str],
        monkeypatch: pytest.MonkeyPatch) -> str:
    monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
    assert main(argv) == 0
    return capsys.readouterr().out


def test_reads_stdin(capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch) -> None:
    assert run([], "Smooth reading works.", capsys, monkeypatch) == (
        "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks."
    )


def test_dash_reads_stdin(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    assert run(["-"], "smooth", capsys, monkeypatch) == "<b>smo</b>oth"


def test_reads_a_file(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    path = tmp_path / "input.txt"
    path.write_text("Smooth reading", encoding="utf-8")
    assert main([str(path)]) == 0
    assert capsys.readouterr().out == "<b>Smo</b>oth <b>read</b>ing"


def test_fixation_and_saccade(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    out = run(["--fixation", "5", "--saccade", "2"], "Smooth reading works.", capsys, monkeypatch)
    assert out == "<b>Smoot</b>h reading <b>work</b>s."


def test_tag_and_class(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    out = run(["--tag", "span", "--class", "sr-fixation"], "smooth", capsys, monkeypatch)
    assert out == '<span class="sr-fixation">smo</span>oth'


def test_markdown(capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch) -> None:
    out = run(["--markdown"], "Smooth reading works.", capsys, monkeypatch)
    assert out == "**Smo**oth **read**ing **wor**ks."


def test_numbers(capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch) -> None:
    assert run(["--numbers"], "2024", capsys, monkeypatch) == "<b>20</b>24"
    assert run([], "2024", capsys, monkeypatch) == "2024"


def test_min_word_length(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    assert run(["--min-word-length", "4"], "the read", capsys, monkeypatch) == "the <b>re</b>ad"


def test_no_ignore_html_tags(
    capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    assert run(["--no-ignore-html-tags"], "<i>hi</i>", capsys, monkeypatch) == (
        "&lt;<b>i</b>&gt;<b>h</b>i&lt;/<b>i</b>&gt;"
    )


def test_missing_file_reports_an_error(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["/definitely/not/here.txt"]) == 1
    assert "smooth-reading:" in capsys.readouterr().err


def test_invalid_fixation_is_rejected() -> None:
    with pytest.raises(SystemExit):
        main(["--fixation", "9"])


def test_invalid_saccade_is_rejected() -> None:
    with pytest.raises(SystemExit):
        main(["--saccade", "0"])
