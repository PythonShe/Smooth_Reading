import { describe, expect, it } from 'vitest';
import { toHtml, tokenize } from '../src/index.js';

const SENTENCE =
  'Smooth reading works, it’s naïve and 2024 is fine — really fine. <em>Tom &amp; Jerry</em> 我喜欢阅读。สวัสดีครับ\n';

function corpus(bytes: number): string {
  const reps = Math.ceil(bytes / SENTENCE.length);
  return SENTENCE.repeat(reps);
}

function time(fn: () => void): number {
  const started = performance.now();
  fn();
  return performance.now() - started;
}

describe('performance sanity', () => {
  const small = corpus(100 * 1024);
  const large = corpus(1024 * 1024);

  it('toHtml handles 1 MB quickly and scales roughly linearly', () => {
    toHtml(small); // warm up JIT and segmenter caches
    const tSmall = time(() => toHtml(small));
    const tLarge = time(() => toHtml(large));
    expect(tLarge).toBeLessThan(5000);
    // 10x the input should not cost more than ~40x the time (generous: CI is noisy).
    expect(tLarge / Math.max(tSmall, 1)).toBeLessThan(40);
  });

  it('tokenize round-trips 1 MB', () => {
    const tokens = tokenize(large);
    let length = 0;
    for (const token of tokens) length += token.text.length;
    expect(length).toBe(large.length);
  });
});
