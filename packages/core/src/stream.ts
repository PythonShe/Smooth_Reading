import { HtmlRenderer } from './html.js';
import type { HtmlOptions } from './types.js';

/**
 * Find how much of `buffer` can safely be rendered right now.
 *
 * Safe means: the cut is on a whitespace boundary (so no word — and no
 * apostrophe- or combining-mark-joined word — is split), and it is not inside
 * an unterminated `<...>` tag.
 *
 * @returns the number of leading characters that may be flushed (may be `0`)
 */
export function safeCutIndex(buffer: string, ignoreHtmlTags: boolean): number {
  let best = 0;
  let inTag = false;
  for (let i = 0; i < buffer.length; i += 1) {
    const code = buffer.charCodeAt(i);
    if (ignoreHtmlTags) {
      if (inTag) {
        if (code === 0x3e /* > */) inTag = false;
        continue;
      }
      if (code === 0x3c /* < */) {
        inTag = true;
        continue;
      }
    }
    if (isWhitespace(code)) best = i + 1;
  }
  return best;
}

/** Space, tab, the C0 line breaks, NBSP and the Unicode space separators. */
function isWhitespace(code: number): boolean {
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

/**
 * A WHATWG `TransformStream<string, string>` that emphasises text as it flows
 * through.
 *
 * Only the tail after the last separator is buffered, so words are never cut in
 * half and `saccade` numbering continues across chunk boundaries. `flush` emits
 * whatever is left.
 *
 * ```ts
 * await readable.pipeThrough(createTransformStream({ fixation: 4 })).pipeTo(sink);
 * ```
 */
export function createTransformStream(
  options?: HtmlOptions,
): TransformStream<string, string> {
  const renderer = new HtmlRenderer(options);
  let buffer = '';

  return new TransformStream<string, string>({
    transform(chunk, controller) {
      buffer += chunk;
      const cut = safeCutIndex(buffer, renderer.ignoreHtmlTags);
      if (cut === 0) return;
      const piece = buffer.slice(0, cut);
      buffer = buffer.slice(cut);
      const out = renderer.render(piece);
      if (out !== '') controller.enqueue(out);
    },
    flush(controller) {
      if (buffer === '') return;
      const out = renderer.render(buffer);
      buffer = '';
      if (out !== '') controller.enqueue(out);
    },
  });
}
