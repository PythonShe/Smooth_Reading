"""``smooth-reading`` command line interface."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from . import __version__
from .html import to_html, to_markdown
from .options import DEFAULTS, Options


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="smooth-reading",
        description=(
            "Emphasise the leading letters of every word so the eye gets an "
            "artificial fixation point. Reads a file or standard input, writes HTML."
        ),
    )
    parser.add_argument("file", nargs="?", help="input file; omit or use '-' for standard input")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
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
    parser.add_argument("--numbers", action="store_true", help="also emphasise digit-only words")
    parser.add_argument("--tag", default="b", help="HTML tag for the fixation; default %(default)s")
    parser.add_argument("--class", dest="class_name", help="class attribute for the fixation tag")
    parser.add_argument(
        "--no-ignore-html-tags",
        dest="ignore_html_tags",
        action="store_false",
        help="treat the input as plain text and escape existing markup",
    )
    parser.add_argument(
        "--markdown", action="store_true", help="emit Markdown (**prefix**rest) instead of HTML"
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    try:
        options = Options(
            fixation=args.fixation,
            saccade=args.saccade,
            min_word_length=args.min_word_length,
            emphasize_numbers=args.numbers,
        )
    except ValueError as error:
        parser.error(str(error))

    try:
        if args.file in (None, "-"):
            text = sys.stdin.read()
        else:
            with open(args.file, encoding="utf-8") as handle:
                text = handle.read()
    except OSError as error:
        print(f"smooth-reading: {error}", file=sys.stderr)
        return 1

    if args.markdown:
        output = to_markdown(text, options)
    else:
        output = to_html(
            text,
            options,
            tag=args.tag,
            class_name=args.class_name,
            ignore_html_tags=args.ignore_html_tags,
        )
    sys.stdout.write(output)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
