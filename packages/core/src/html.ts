import { resolveRenderOptions, type ResolvedRenderOptions } from './defaults.js';
import { createState, tokenizeWithState, type TokenizeState } from './tokenize.js';
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

/** Render a single token to markup. */
export function renderToken(token: Token, opts: ResolvedRenderOptions): string {
  if (token.type === 'separator') return escapeHtml(token.text);
  if (token.fixation === 0) return escapeHtml(token.text);

  const head =
    openTag(opts.tag, opts.className) +
    escapeHtml(token.fixationText) +
    `</${opts.tag}>`;
  if (token.restText === '') return head;
  const rest =
    opts.restTag === undefined
      ? escapeHtml(token.restText)
      : openTag(opts.restTag, opts.restClassName) +
        escapeHtml(token.restText) +
        `</${opts.restTag}>`;
  return head + rest;
}

function renderText(
  text: string,
  opts: ResolvedRenderOptions,
  state: TokenizeState,
): string {
  let out = '';
  for (const token of tokenizeWithState(text, opts, state)) {
    out += renderToken(token, opts);
  }
  return out;
}

const TAG_RE = /<[^>]*>/g;
const TAG_NAME_RE = /^<\s*(\/?)\s*([a-zA-Z][^\s/>]*)/;

/**
 * Elements whose contents are never rewritten: the configured `skipTags` plus
 * the emphasis tag itself, so that markup which is already emphasised is never
 * wrapped a second time (SPEC §4, "does not double-wrap").
 */
function skipSet(opts: ResolvedRenderOptions): Set<string> {
  const set = new Set<string>();
  for (const name of opts.skipTags) set.add(name.toLowerCase());
  set.add(opts.tag.toLowerCase());
  return set;
}

/**
 * Stateful HTML renderer.
 *
 * Everything that must survive across calls lives here: the saccade counter and
 * the "am I inside a skipped element?" bookkeeping. `toHtml` creates one and
 * feeds it the whole string; `createTransformStream` creates one and feeds it
 * chunk after chunk, which is why the two produce identical output.
 */
export class HtmlRenderer {
  readonly opts: ResolvedRenderOptions;
  readonly ignoreHtmlTags: boolean;
  private readonly skip: Set<string>;
  private readonly state: TokenizeState;
  private skipName: string | null = null;
  private skipDepth = 0;

  constructor(options?: HtmlOptions) {
    this.opts = resolveRenderOptions(options);
    this.ignoreHtmlTags = options?.ignoreHtmlTags ?? true;
    this.skip = skipSet(this.opts);
    this.state = createState();
  }

  /**
   * Render one complete piece of input. The caller must guarantee that the
   * piece does not end in the middle of a word or a tag.
   */
  render(text: string): string {
    if (text === '') return '';
    if (!this.ignoreHtmlTags) return renderText(text, this.opts, this.state);

    let out = '';
    let cursor = 0;
    TAG_RE.lastIndex = 0;
    for (let match = TAG_RE.exec(text); match !== null; match = TAG_RE.exec(text)) {
      const before = text.slice(cursor, match.index);
      out += this.skipName === null ? renderText(before, this.opts, this.state) : before;

      const raw = match[0];
      out += raw;
      cursor = match.index + raw.length;
      this.consumeTag(raw);
    }

    const tail = text.slice(cursor);
    out += this.skipName === null ? renderText(tail, this.opts, this.state) : tail;
    return out;
  }

  private consumeTag(raw: string): void {
    const parsed = TAG_NAME_RE.exec(raw);
    if (!parsed) return;
    const closing = parsed[1] === '/';
    const name = (parsed[2] ?? '').toLowerCase();
    const selfClosing = /\/\s*>$/.test(raw);

    if (this.skipName !== null) {
      if (name !== this.skipName || selfClosing) return;
      if (closing) {
        this.skipDepth -= 1;
        if (this.skipDepth <= 0) {
          this.skipName = null;
          this.skipDepth = 0;
        }
      } else {
        this.skipDepth += 1;
      }
      return;
    }

    if (!closing && !selfClosing && this.skip.has(name)) {
      this.skipName = name;
      this.skipDepth = 1;
    }
  }
}

/**
 * Turn `text` into HTML, emphasising the fixation prefix of every word
 * (SPEC §4).
 *
 * With `ignoreHtmlTags: true` (the default) anything that looks like a tag is
 * passed through verbatim and never escaped; the text between tags is
 * tokenized. Text inside `skipTags` elements — and inside elements using the
 * emphasis `tag` — is emitted exactly as it was, so already-emphasised markup is
 * never wrapped twice.
 */
export function toHtml(text: string, options?: HtmlOptions): string {
  return new HtmlRenderer(options).render(text);
}
