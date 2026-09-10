"""HTML and Markdown rendering (docs/SPEC.md section 4)."""

from __future__ import annotations

import html
import re
from collections.abc import Iterable, Iterator
from typing import Any

from .core import Token, tokenize_from
from .options import Options, resolve

#: Elements whose text content ``to_html`` never touches (spec section 4).
SKIP_TAGS: tuple[str, ...] = ("code", "pre", "script", "style", "kbd", "samp", "textarea")

# Markup that is passed through verbatim when ``ignore_html_tags`` is on: a
# comment, a CDATA section, a tag (``<`` only starts one when followed by a
# letter, ``/``, ``!`` or ``?``) that ends at the next ``>``, or a character
# reference. Anything else -- including an unterminated ``<p`` -- is text and
# gets escaped. An unterminated comment or CDATA block degrades to an ordinary
# declaration ending at the first ``>``, exactly as in the TypeScript core.
_MARKUP = re.compile(
    r"<!--.*?-->"
    r"|<!\[CDATA\[.*?\]\]>"
    r"|<[/!?][^>]*>"
    r"|<[A-Za-z][^>]*>"
    r"|&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);",
    re.DOTALL,
)
# A tag name runs from the first letter until whitespace, ``/`` or ``>``, so
# ``<code.x>`` is named ``code.x`` (not the skip tag ``code``) and ``</ code>``
# is a closing ``code`` tag. Mirrors ``TAG_NAME_RE`` in the core's html.ts.
_TAG = re.compile(r"<\s*(/?)\s*([A-Za-z][^\s/>]*)")
#: ``<br/>`` and ``<code / >`` are self-closing; the trailing ``/`` may be spaced.
_SELF_CLOSING = re.compile(r"/\s*>$")


def _escape(text: str) -> str:
    # The spec escapes exactly ``& < > "`` (not ``'``, so ``don't`` stays readable).
    return html.escape(text, quote=False).replace('"', "&quot;")


def _split_markup(text: str, skip_tags: Iterable[str]) -> Iterator[tuple[bool, str]]:
    """Yield ``(is_raw, chunk)`` pairs covering ``text``.

    Raw chunks (markup, character references and the content of ``skip_tags``
    elements) are emitted verbatim; the others are prose to be tokenized.
    Character references therefore act as word boundaries.
    """
    skipped = {name.lower() for name in skip_tags}
    skip_name: str | None = None  # the skip element we are inside, if any
    skip_depth = 0  # nesting of that same element, e.g. <pre><pre>..</pre></pre>
    cursor = 0
    for match in _MARKUP.finditer(text):
        if match.start() > cursor:
            yield skip_name is not None, text[cursor : match.start()]
        raw = match.group()
        yield True, raw
        cursor = match.end()

        tag = _TAG.match(raw)
        if tag is None:
            continue
        closing, name = tag.group(1) == "/", tag.group(2).lower()
        if _SELF_CLOSING.search(raw):  # self-closing, e.g. <br/> or <code / >
            continue
        if skip_name is None:
            if not closing and name in skipped:
                skip_name, skip_depth = name, 1
        elif name == skip_name:
            skip_depth += -1 if closing else 1
            if skip_depth == 0:
                skip_name = None
    if cursor < len(text):
        yield skip_name is not None, text[cursor:]


def _wrap(tag: str | None, class_name: str | None, body: str) -> str:
    if tag is None:
        return body
    attribute = "" if class_name is None else f' class="{_escape(class_name)}"'
    return f"<{tag}{attribute}>{body}</{tag}>"


def _render(
    tokens: Iterable[Token],
    tag: str,
    class_name: str | None,
    rest_tag: str | None,
    rest_class_name: str | None,
) -> str:
    parts: list[str] = []
    for token in tokens:
        if token.fixation == 0:
            parts.append(_escape(token.text))
            continue
        parts.append(_wrap(tag, class_name, _escape(token.fixation_text)))
        if token.rest_text:  # a fully emphasised word gets no (empty) rest element
            parts.append(_wrap(rest_tag, rest_class_name, _escape(token.rest_text)))
    return "".join(parts)


def to_html(
    text: str,
    options: Options | None = None,
    *,
    tag: str = "b",
    class_name: str | None = None,
    rest_tag: str | None = None,
    rest_class_name: str | None = None,
    ignore_html_tags: bool = True,
    skip_tags: Iterable[str] = SKIP_TAGS,
    **overrides: Any,
) -> str:
    """Render ``text`` as HTML with the leading part of each word emphasised.

    Each fixation is wrapped in ``tag`` (with ``class_name``); the rest of the
    word is plain text unless ``rest_tag`` is given. Everything emitted as text
    has ``& < > "`` escaped.

    With ``ignore_html_tags`` (the default) existing tags and character
    references pass through verbatim, the content of ``skip_tags`` elements --
    plus ``tag``/``rest_tag`` themselves, so already-emphasised markup is not
    wrapped twice -- is left untouched, and the saccade count continues across
    markup. With ``ignore_html_tags=False`` the input is plain text and every
    ``<``, ``>`` and ``&`` is escaped.
    """
    opts = resolve(options, overrides)
    if not ignore_html_tags:
        tokens, _ = tokenize_from(text, opts, 0)
        return _render(tokens, tag, class_name, rest_tag, rest_class_name)

    implicit = (tag, rest_tag) if rest_tag is not None else (tag,)
    parts: list[str] = []
    word_index = 0
    for is_raw, chunk in _split_markup(text, (*skip_tags, *implicit)):
        if is_raw:
            parts.append(chunk)
        else:
            tokens, word_index = tokenize_from(chunk, opts, word_index)
            parts.append(_render(tokens, tag, class_name, rest_tag, rest_class_name))
    return "".join(parts)


def to_markdown(
    text: str,
    options: Options | None = None,
    *,
    marker: str = "**",
    **overrides: Any,
) -> str:
    """Render ``text`` as Markdown, wrapping each fixation in ``marker``.

    Nothing is escaped; the input is assumed to be Markdown already.
    """
    tokens, _ = tokenize_from(text, resolve(options, overrides), 0)
    return "".join(
        f"{marker}{token.fixation_text}{marker}{token.rest_text}" if token.fixation else token.text
        for token in tokens
    )
