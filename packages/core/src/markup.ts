/**
 * The HTML lexing rules from SPEC §4, shared by `toHtml` (whole string) and
 * `createTransformStream` (incremental) so the two can never disagree:
 *
 * - `<` starts markup only when followed by a letter, `/`, `!` or `?`; the
 *   markup ends at the next `>` (or `-->` for a `<!--` comment). An
 *   unterminated `<` is text.
 * - `&` starts a character reference only when it forms `&name;`, `&#123;`
 *   or `&#x1F;`; anything else is a bare ampersand and gets escaped.
 */

/** `true` when the `<` at `text[i]` begins a tag, comment or declaration. */
export function isTagStart(text: string, i: number): boolean {
  const c = text.charCodeAt(i + 1);
  return (
    (c >= 0x41 && c <= 0x5a) || // A-Z
    (c >= 0x61 && c <= 0x7a) || // a-z
    c === 0x2f || // /
    c === 0x21 || // !
    c === 0x3f // ?
  );
}

/**
 * Markup blocks that may contain a bare `>`: comments and CDATA sections.
 * Each entry is `[opener, terminator]`.
 */
export const BLOCKS: ReadonlyArray<readonly [string, string]> = [
  ['<!--', '-->'],
  ['<![CDATA[', ']]>'],
];

/** Longest block opener; the stream scanner needs that much lookahead. */
export const MAX_OPENER = 9;

/** The block opened at `text[i]`, or `undefined` for an ordinary tag. */
export function blockAt(text: string, i: number): readonly [string, string] | undefined {
  return BLOCKS.find(([opener]) => text.startsWith(opener, i));
}

/**
 * Index just past the end of the markup starting at `text[i]` (which must be a
 * tag start), or `-1` when it is not terminated within `text`. An unterminated
 * comment or CDATA block degrades to an ordinary `<!...>` declaration.
 */
export function findTagEnd(text: string, i: number): number {
  const block = blockAt(text, i);
  if (block) {
    const close = text.indexOf(block[1], i + block[0].length);
    if (close >= 0) return close + block[1].length;
  }
  const close = text.indexOf('>', i + 1);
  return close < 0 ? -1 : close + 1;
}

const ENTITY_RE = /&(?:[a-zA-Z][a-zA-Z0-9]*|#[0-9]+|#[xX][0-9a-fA-F]+);/y;

/**
 * Index just past the character reference starting at `text[i]` (an `&`), or
 * `-1` when it is a bare ampersand.
 */
export function findEntityEnd(text: string, i: number): number {
  ENTITY_RE.lastIndex = i;
  return ENTITY_RE.test(text) ? ENTITY_RE.lastIndex : -1;
}

/** Space, tab, the C0 line breaks, NBSP and the Unicode space separators. */
export function isWhitespace(code: number): boolean {
  return (
    code === 0x20 ||
    (code >= 0x09 && code <= 0x0d) ||
    code === 0xa0 ||
    code === 0x1680 ||
    (code >= 0x2000 && code <= 0x200a) ||
    code === 0x2028 ||
    code === 0x2029 ||
    code === 0x202f ||
    code === 0x205f ||
    code === 0x3000
  );
}
