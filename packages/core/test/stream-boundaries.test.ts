import { describe, expect, it } from 'vitest';
import { createTransformStream, toHtml } from '../src/index.js';
import type { HtmlOptions } from '../src/index.js';

/** Feed the exact `pieces` and collect what comes out, chunk by chunk. */
async function feed(pieces: string[], options?: HtmlOptions): Promise<string[]> {
  const stream = createTransformStream(options);
  const writer = stream.writable.getWriter();
  const reader = stream.readable.getReader();
  const out: string[] = [];
  const drain = (async () => {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      out.push(value);
    }
  })();
  for (const piece of pieces) await writer.write(piece);
  await writer.close();
  await drain;
  return out;
}

const HIGH_SURROGATE = /[\uD800-\uDBFF]$/;
const LEADING_LOW_SURROGATE = /^[\uDC00-\uDFFF]/;
const LEADING_MARK = /^\p{M}/u;

describe('createTransformStream chunk boundaries', () => {
  it('never splits a decomposed grapheme cluster (chunk ends between i and U+0308)', async () => {
    const pieces = ['smooth nai', '̈ve reading'];
    const out = await feed(pieces);
    expect(out.join('')).toBe(toHtml(pieces.join('')));
    expect(out.join('')).toContain('<b>naï</b>ve');
    for (const chunk of out) expect(chunk).not.toMatch(LEADING_MARK);
  });

  it('never splits a surrogate pair (chunk ends on a high surrogate)', async () => {
    const emoji = '\u{1F44B}';
    const [hi, lo] = [emoji.charAt(0), emoji.charAt(1)];
    const pieces = ['hello ' + hi, lo + ' world'];
    const out = await feed(pieces);
    expect(out.join('')).toBe(toHtml(pieces.join('')));
    for (const chunk of out) {
      expect(chunk).not.toMatch(HIGH_SURROGATE);
      expect(chunk).not.toMatch(LEADING_LOW_SURROGATE);
    }
  });

  it('never splits a character reference', async () => {
    const pieces = ['Tom &am', 'p; Jerry &#x2', '7; ok'];
    const out = await feed(pieces);
    expect(out.join('')).toBe(toHtml(pieces.join('')));
    expect(out.join('')).toBe('<b>To</b>m &amp; <b>Jer</b>ry &#x27; <b>o</b>k');
  });

  it('never splits a tag, comment or CDATA section', async () => {
    const input = '<p>a <!-- x > y --> b <![CDATA[ > ]]> c<br/>d</p>';
    for (const size of [1, 2, 3, 4, 5, 8, 13]) {
      const pieces: string[] = [];
      for (let i = 0; i < input.length; i += size) pieces.push(input.slice(i, i + size));
      const out = await feed(pieces);
      expect(out.join(''), `chunk size ${size}`).toBe(toHtml(input));
    }
  });

  it('keeps "\\r\\n" together and continues after an unterminated "<"', async () => {
    const pieces = ['a\r', '\nb <', 'c d', ' e'];
    const out = await feed(pieces);
    expect(out.join('')).toBe(toHtml(pieces.join('')));
    for (const chunk of out) expect(chunk).not.toMatch(/\r$/);
  });

  it('handles a stray "<" that is never a tag when tags are ignored', async () => {
    const pieces = ['5 <', ' 6 and', ' more'];
    const out = await feed(pieces);
    expect(out.join('')).toBe('5 &lt; 6 <b>an</b>d <b>mo</b>re');
  });

  it('is linear on input with no separators at all', async () => {
    const chunk = 'a'.repeat(1024);
    const pieces = Array.from({ length: 512 }, () => chunk); // 512 KB, one word
    const started = performance.now();
    const out = await feed(pieces);
    const elapsed = performance.now() - started;
    expect(out.join('')).toBe(toHtml(pieces.join('')));
    expect(elapsed).toBeLessThan(2000);
  });
});
