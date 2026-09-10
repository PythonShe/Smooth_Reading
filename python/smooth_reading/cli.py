"""Command line interface for smooth-reading."""

from __future__ import annotations

import argparse
import sys
from typing import Optional, Sequence

from .html import to_html, to_markdown
from .options import DEFAULTS, Options

__all__ = ["build_parser", "main"]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="smooth-reading",
        description=(
            "Emphasise the leading letters of every word so the eye gets an "
            "artificial fixation point. Reads a file or standard input."
        ),
    )
    parser.add_argument(
        "file",
        nargs="?",
        help="input file; omit or use '-' to read standard input",
    )
    parser.add_argument(
        "--fixation",
        type=int,
        choices=[1, 2, 3, 4, 5],
        default=DEFAULTS.fixation,
        help="fixation strength, 1 (weakest) to 5 (strongest); default %(default)s",
    )
    parser.add_argument(
        "--saccade",
        type=int,
        default=DEFAULTS.saccade,
        help="emphasise every Nth word; default %(default)s",
    )
    parser.add_argument(
        "--min-word-length",
        type=int,
        default=DEFAULTS.min_word_length,
        help="skip words shorter than this; default %(default)s",
    )
    parser.add_argument("--tag", default="b", help="HTML tag for the fixation; default b")
    parser.add_argument(
        "--class",
        dest="class_name",
        default=None,
        help="class attribute for the fixation element",
    )
    parser.add_argument(
        "--markdown",
        action="store_true",
        help="emit Markdown (**prefix**rest) instead of HTML",
    )
    parser.add_argument(
        "--numbers",
        action="store_true",
        help="also emphasise words made only of digits",
    )
    parser.add_argument(
        "--no-ignore-html-tags",
        dest="ignore_html_tags",
        action="store_false",
        help="treat the input as plain text and escape existing markup",
    )
    return parser


def _read(path: Optional[str]) -> str:
    if path is None or path == "-":
        return sys.stdin.read()
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        options = Options(
            fixation=args.fixation,
            saccade=args.saccade,
            min_word_length=args.min_word_length,
            emphasize_numbers=args.numbers,
        )
    except ValueError as error:
        build_parser().error(str(error))
        return 2  # pragma: no cover - argparse.error raises SystemExit
    try:
        text = _read(args.file)
    except OSError as error:
        print(f"smooth-reading: {error}", file=sys.stderr)
        return 1
    if args.markdown:
        sys.stdout.write(to_markdown(text, options=options))
    else:
        sys.stdout.write(
            to_html(
                text,
                tag=args.tag,
                class_name=args.class_name,
                ignore_html_tags=args.ignore_html_tags,
                options=options,
            )
        )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
