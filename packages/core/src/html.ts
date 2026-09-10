import { resolveMarkupOptions, type ResolvedMarkupOptions } from './defaults.js';
import { findEntityEnd, findTagEnd, isTagStart } from './markup.js';
import { tokenizeWithState, type TokenizeState } from './tokenize.js';
import type { HtmlOptions, Token } from './types.js';

const ESCAPES: Readonly<Record<string, string>> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
};

/** Escape the four characters SPEC §4 requires escaping in emitted text. */
export function escapeHtml(text: string): string {
  return text.replace(/[&<>"]/g, (ch) => ESCAPES[ch] ?? ch);
}

function openTag(name: string, className: string | undefined): string {
  return className === undefined
    ? `<${name}>`
    : `<${name} class="${escapeHtml(className)}">`;
}

function renderToken(token: Token, opts: ResolvedMarkupOptions): string {
  if (token.type === 'separator' || token.fixation === 0) return escapeHtml(token.text);

  const head =
    openTag(opts.tag, opts.className) + escapeHtml(token.fixationText) + `</${opts.tag}>`;
  if (token.restText === '') return head;
  if (opts.restTag === undefined) return head + escapeHtml(token.restText);
  return (
    head +
    openTag(opts.restTag, opts.restClassName) +
    escapeHtml(token.restText) +
    `</${opts.restTag}>`
  );
}

/** Where the next tag or character reference *might* start. */
const SPECIAL_RE = /[<&]/g;
const TAG_NAME_RE = /^<\s*(\/?)\s*([a-zA-Z][^\s/>]*)/;

/**
 * Stateful HTML renderer.
 *
 * Everything that must survive across calls lives here: the saccade counter and
 * the "am I inside a skipped element?" bookkeeping. `toHtml` creates one and
 * feeds it the whole string; `createTransformStream` creates one and feeds it
 * chunk after chunk, which is why the two produce identical output.
 */
export class HtmlRenderer {
  readonly ignoreHtmlTags: boolean;
  private readonly opts: ResolvedMarkupOptions;
  private readonly skip: Set<string>;
  private readonly state: TokenizeState = { wordIndex: 0 };
  private skipName: string | null = null;
  private skipDepth = 0;

  constructor(options?: HtmlOptions) {
    this.opts = resolveMarkupOptions(options);
    this.ignoreHtmlTags = options?.ignoreHtmlTags ?? true;
    // The emphasis tags themselves are skipped so that already-emphasised
    // markup is never wrapped a second time (SPEC §4).
    this.skip = new Set(this.opts.skipTags.map((name) => name.toLowerCase()));
    this.skip.add(this.opts.tag.toLowerCase());
    if (this.opts.restTag !== undefined) this.skip.add(this.opts.restTag.toLowerCase());
  }

  /**
   * Render one complete piece of input. The caller must guarantee that the
   * piece does not end in the middle of a word, a tag or a character reference.
   */
  render(text: string): string {
    if (text === '') return '';
    if (!this.ignoreHtmlTags) return this.renderText(text);

    let out = '';
    let cursor = 0;
    SPECIAL_RE.lastIndex = 0;
    for (let m = SPECIAL_RE.exec(text); m !== null; m = SPECIAL_RE.exec(text)) {
      const start = m.index;
      const isTag = text.charCodeAt(start) === 0x3c; /* < */
      if (isTag && !isTagStart(text, start)) continue;
      const end = isTag ? findTagEnd(text, start) : findEntityEnd(text, start);
      if (end < 0) continue; // unterminated: plain text

      out += this.renderText(text.slice(cursor, start));
      const raw = text.slice(start, end);
      out += raw; // verbatim
      if (isTag) this.consumeTag(raw);
      cursor = end;
      SPECIAL_RE.lastIndex = end;
    }
    return out + this.renderText(text.slice(cursor));
  }

  /** Tokenize and render text, or pass it through when inside a skipped element. */
  private renderText(text: string): string {
    if (text === '' || this.skipName !== null) return text;
    let out = '';
    for (const token of tokenizeWithState(text, this.opts, this.state)) {
      out += renderToken(token, this.opts);
    }
    return out;
  }

  private consumeTag(raw: string): void {
    const parsed = TAG_NAME_RE.exec(raw);
    if (!parsed) return;
    const closing = parsed[1] === '/';
    const name = (parsed[2] ?? '').toLowerCase();
    const selfClosing = /\/\s*>$/.test(raw);

    if (this.skipName === null) {
      if (!closing && !selfClosing && this.skip.has(name)) {
        this.skipName = name;
        this.skipDepth = 1;
      }
      return;
    }
    if (name !== this.skipName || selfClosing) return;
    if (!closing) {
      this.skipDepth += 1;
    } else if ((this.skipDepth -= 1) <= 0) {
      this.skipName = null;
      this.skipDepth = 0;
    }
  }
}

/**
 * Turn `text` into HTML, emphasising the fixation prefix of every word
 * (SPEC §4).
 *
 * With `ignoreHtmlTags: true` (the default) tags and character references are
 * passed through verbatim and the text between them is tokenized; text inside
 * `skipTags` — and inside `tag`/`restTag` elements — is left exactly as it was,
 * so already-emphasised markup is never wrapped twice. With
 * `ignoreHtmlTags: false` the input is plain text and fully escaped.
 *
 * @example
 * ```ts
 * toHtml('Smooth reading works.'); // '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
 * ```
 */
export function toHtml(text: string, options?: HtmlOptions): string {
  return new HtmlRenderer(options).render(text);
}
