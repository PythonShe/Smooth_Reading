"""HTML rendering (spec section 4)."""

from __future__ import annotations

import re
from typing import Any, Iterator, Mapping, Optional, Sequence

from .core import iter_tokens
from .options import Options, coerce_options

__all__ = ["SKIP_TAGS", "escape", "to_html", "to_markdown"]

#: Elements whose text content is never touched.
SKIP_TAGS: tuple[str, ...] = ("code", "pre", "script", "style", "kbd", "samp", "textarea")

_ENTITY = re.compile(r"&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);")
_TAG_NAME = re.compile(r"^</?\s*([A-Za-z][A-Za-z0-9:-]*)")
_ESCAPES = {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}


def escape(text: str) -> str:
    """Escape ``&``, ``<``, ``>`` and ``"`` in emitted text."""
    return "".join(_ESCAPES.get(char, char) for char in text)


def _scan_markup(text: str, index: int) -> int:
    """Return the end index of the markup construct starting at ``text[index] == '<'``.

    Returns ``index`` when what follows is not markup (a bare ``<`` in prose).
    """
    rest = text[index:]
    if rest.startswith("<!--"):
        end = text.find("-->", index + 4)
        return len(text) if end == -1 else end + 3
    if rest.startswith("<![CDATA["):
        end = text.find("]]>", index + 9)
        return len(text) if end == -1 else end + 3
    following = text[index + 1 : index + 2]
    if not (following.isalpha() or following in "!/?"):
        return index
    if following == "/" and not text[index + 2 : index + 3].isalpha():
        return index
    end = text.find(">", index + 1)
    return len(text) if end == -1 else end + 1


def _chunks(text: str, skip_tags: Sequence[str]) -> Iterator[tuple[bool, str]]:
    """Yield ``(is_raw, chunk)`` covering ``text``; raw chunks pass through verbatim."""
    skip_lower = {tag.lower() for tag in skip_tags}
    skip_stack: list[str] = []
    buffer: list[str] = []
    length = len(text)
    index = 0

    def flush() -> Iterator[tuple[bool, str]]:
        if buffer:
            yield bool(skip_stack), "".join(buffer)
            buffer.clear()

    while index < length:
        char = text[index]
        if char == "<":
            end = _scan_markup(text, index)
            if end > index:
                yield from flush()
                markup = text[index:end]
                match = _TAG_NAME.match(markup)
                if match is not None:
                    name = match.group(1).lower()
                    if markup.startswith("</"):
                        if name in skip_stack:
                            while skip_stack and skip_stack.pop() != name:
                                pass
                    elif name in skip_lower and not markup.rstrip().endswith("/>"):
                        skip_stack.append(name)
                yield True, markup
                index = end
                continue
        elif char == "&" and not skip_stack:
            match = _ENTITY.match(text, index)
            if match is not None:
                yield from flush()
                yield True, match.group(0)
                index = match.end()
                continue
        buffer.append(char)
        index += 1
    yield from flush()


def _wrap(tag: Optional[str], class_name: Optional[str], body: str) -> str:
    if tag is None:
        return body
    attrs = f' class="{escape(class_name)}"' if class_name is not None else ""
    return f"<{tag}{attrs}>{body}</{tag}>"


def to_html(
    text: str,
    tag: str = "b",
    class_name: Optional[str] = None,
    rest_tag: Optional[str] = None,
    rest_class_name: Optional[str] = None,
    ignore_html_tags: bool = True,
    skip_tags: Sequence[str] = SKIP_TAGS,
    options: Optional[Options | Mapping[str, Any]] = None,
    **overrides: Any,
) -> str:
    """Render ``text`` as HTML with the leading part of each word emphasised.

    With ``ignore_html_tags`` (the default) markup, character entities and the
    content of ``skip_tags`` are passed through verbatim; everything else is
    escaped. Set it to ``False`` to treat the whole input as plain text.
    """
    opts = coerce_options(options, **overrides)
    parts: list[str] = []
    word_index = 0
    stream: Iterator[tuple[bool, str]]
    stream = _chunks(text, skip_tags) if ignore_html_tags else iter([(False, text)])
    for is_raw, chunk in stream:
        if is_raw:
            parts.append(chunk)
            continue
        for token, word_index in iter_tokens(chunk, opts, word_index):
            if token.fixation > 0:
                parts.append(_wrap(tag, class_name, escape(token.fixation_text)))
                if token.rest_text:
                    parts.append(_wrap(rest_tag, rest_class_name, escape(token.rest_text)))
            else:
                parts.append(escape(token.text))
    return "".join(parts)


def to_markdown(
    text: str,
    marker: str = "**",
    options: Optional[Options | Mapping[str, Any]] = None,
    **overrides: Any,
) -> str:
    """Render ``text`` as Markdown, emphasising each fixation with ``marker``."""
    opts = coerce_options(options, **overrides)
    parts: list[str] = []
    word_index = 0
    for token, word_index in iter_tokens(text, opts, word_index):
        if token.fixation > 0:
            parts.append(f"{marker}{token.fixation_text}{marker}{token.rest_text}")
        else:
            parts.append(token.text)
    return "".join(parts)
