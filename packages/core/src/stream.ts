import { HtmlRenderer } from './html.js';
import { blockAt, isTagStart, isWhitespace, MAX_OPENER } from './markup.js';
import type { HtmlOptions } from './types.js';

/**
 * Incremental scanner that finds how much of a growing buffer can be rendered
 * right now without splitting a word, a grapheme cluster, a tag or a character
 * reference.
 *
 * A cut is only ever placed right after whitespace, and only outside markup.
 * Words, apostrophe-joined words, combining marks, surrogate pairs and
 * `&entity;` references contain no whitespace, so they are never split;
 * `\r\n` (a single grapheme cluster) is kept together explicitly. Every
 * character is examined once, so a stream of any length costs linear time.
 */
class CutScanner {
  private mode: 'text' | 'tag' | 'block' = 'text';
  /** Terminator of the comment/CDATA block being scanned. */
  private terminator = '';
  /** Characters of the current buffer already examined. */
  private scanned = 0;

  constructor(private readonly html: boolean) {}

  /** Number of leading characters of `buffer` that may be rendered now. */
  cut(buffer: string): number {
    let best = 0;
    let i = this.scanned;
    const n = buffer.length;
    scan: while (i < n) {
      const code = buffer.charCodeAt(i);
      switch (this.mode) {
        case 'tag':
          if (code === 0x3e /* > */) this.mode = 'text';
          i += 1;
          break;
        case 'block':
          if (n - i < this.terminator.length) break scan; // need the whole terminator
          if (buffer.startsWith(this.terminator, i)) {
            this.mode = 'text';
            i += this.terminator.length;
          } else {
            i += 1;
          }
          break;
        default:
          if (this.html && code === 0x3c /* < */) {
            if (n - i < MAX_OPENER) break scan; // cannot yet tell "<" from "<!--"
            if (isTagStart(buffer, i)) {
              const block = blockAt(buffer, i);
              if (block) {
                this.mode = 'block';
                this.terminator = block[1];
                i += block[0].length;
              } else {
                this.mode = 'tag';
                i += 2;
              }
              break;
            }
          }
          if (isWhitespace(code)) {
            if (code === 0x0d /* \r */) {
              if (i + 1 >= n) break scan; // "\r\n" must stay together
              if (buffer.charCodeAt(i + 1) === 0x0a) {
                i += 2;
                best = i;
                break;
              }
            }
            best = i + 1;
          }
          i += 1;
      }
    }
    this.scanned = i - best;
    return best;
  }
}

/**
 * A WHATWG `TransformStream<string, string>` that emphasises text as it flows
 * through, with output identical to `toHtml` of the concatenated input.
 *
 * Only the tail after the last safe boundary is buffered, so a word is never
 * cut in half and `saccade` numbering continues across chunks; `flush` emits
 * whatever is left.
 *
 * @example
 * ```ts
 * await response.body!
 *   .pipeThrough(new TextDecoderStream())
 *   .pipeThrough(createTransformStream({ fixation: 4 }))
 *   .pipeTo(sink);
 * ```
 */
export function createTransformStream(
  options?: HtmlOptions,
): TransformStream<string, string> {
  const renderer = new HtmlRenderer(options);
  const scanner = new CutScanner(renderer.ignoreHtmlTags);
  let buffer = '';

  return new TransformStream<string, string>({
    transform(chunk, controller) {
      buffer += chunk;
      const cut = scanner.cut(buffer);
      if (cut === 0) return;
      const out = renderer.render(buffer.slice(0, cut));
      buffer = buffer.slice(cut);
      if (out !== '') controller.enqueue(out);
    },
    flush(controller) {
      const out = renderer.render(buffer);
      buffer = '';
      if (out !== '') controller.enqueue(out);
    },
  });
}
