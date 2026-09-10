import { describe, expect, it } from 'vitest';
import { createTransformStream, toHtml } from '../src/index.js';
import type { HtmlOptions } from '../src/index.js';
import { loadFixtures } from './fixtures.js';

async function pipe(
  input: string,
  chunkSize: number,
  options?: HtmlOptions,
): Promise<string[]> {
  const stream = createTransformStream(options);
  const writer = stream.writable.getWriter();
  const reader = stream.readable.getReader();
  const chunks: string[] = [];

  const drain = (async () => {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value !== undefined) chunks.push(value);
    }
  })();

  for (let i = 0; i < input.length; i += chunkSize) {
    await writer.write(input.slice(i, i + chunkSize));
  }
  await writer.close();
  await drain;
  return chunks;
}

const CHUNKY = 3;

describe('createTransformStream', () => {
  it('is a WHATWG TransformStream', () => {
    const stream = createTransformStream();
    expect(stream.readable).toBeInstanceOf(ReadableStream);
    expect(stream.writable).toBeInstanceOf(WritableStream);
  });

  it('produces nothing for an empty input', async () => {
    expect(await pipe('', CHUNKY)).toEqual([]);
  });

  it('matches toHtml when fed in awkward 3-character chunks', async () => {
    const input =
      'Smooth reading works, it’s naïve and 2024 is fine — really fine.\nNew line too.';
    const chunks = await pipe(input, CHUNKY);
    expect(chunks.join('')).toBe(toHtml(input));
    expect(chunks.length).toBeGreaterThan(1);
  });

  it('never emits a word cut in half', async () => {
    const chunks = await pipe('Smooth reading works.', CHUNKY);
    for (const chunk of chunks) {
      expect(chunk).not.toMatch(/<b>[^<]*$/);
    }
  });

  it('keeps saccade numbering across chunk boundaries', async () => {
    const input = 'Read 42 books in 2024 now.';
    const options: HtmlOptions = { saccade: 2 };
    const chunks = await pipe(input, CHUNKY, options);
    expect(chunks.join('')).toBe(toHtml(input, options));
  });

  it('does not split an HTML tag', async () => {
    const input = '<p>Smooth <em>reading</em> works.</p>';
    const chunks = await pipe(input, CHUNKY);
    expect(chunks.join('')).toBe(toHtml(input));
    for (const chunk of chunks) {
      expect(chunk.split('<').length).toBe(chunk.split('>').length);
    }
  });

  it('flushes a trailing word with no separator after it', async () => {
    const chunks = await pipe('reading', CHUNKY);
    expect(chunks.join('')).toBe(toHtml('reading'));
  });

  for (const size of [1, 2, 3, 5, 7, 64]) {
    it(`matches toHtml for every common fixture at chunk size ${size}`, async () => {
      for (const { cases } of loadFixtures('common')) {
        for (const fixture of cases) {
          const chunks = await pipe(fixture.input, size, fixture.options);
          expect(chunks.join(''), fixture.name).toBe(fixture.html);
        }
      }
    });
  }
});
