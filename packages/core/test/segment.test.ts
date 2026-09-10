import { afterEach, describe, expect, it, vi } from 'vitest';
import { toHtml, tokenize, usesIntlSegmenter } from '../src/index.js';
import { loadFixtures } from './fixtures.js';

const realSegmenter = Intl.Segmenter;

afterEach(() => {
  Object.defineProperty(Intl, 'Segmenter', { value: realSegmenter, configurable: true, writable: true });
  vi.restoreAllMocks();
});

function removeSegmenter(): void {
  Object.defineProperty(Intl, 'Segmenter', { value: undefined, configurable: true, writable: true });
}

describe('segmenter selection', () => {
  it('is decided at call time, not at import time', () => {
    expect(usesIntlSegmenter()).toBe(true);
    removeSegmenter();
    expect(usesIntlSegmenter()).toBe(false);
    expect(toHtml('Smooth reading')).toBe('<b>Smo</b>oth <b>read</b>ing');
  });

  it('regex fallback passes every common fixture', () => {
    removeSegmenter();
    for (const { cases } of loadFixtures('common')) {
      for (const fixture of cases) {
        expect(toHtml(fixture.input, fixture.options), fixture.name).toBe(fixture.html);
      }
    }
  });

  it('regex fallback keeps surrogate pairs intact when counting', () => {
    removeSegmenter();
    // 𝒜𝒷𝒸𝒹 are Mathematical letters (\p{L}), two UTF-16 units each; 4 code points -> prefix 2.
    const [word] = tokenize('𝒜𝒷𝒸𝒹');
    expect(word).toMatchObject({ type: 'word', fixation: 2, fixationText: '𝒜𝒷', restText: '𝒸𝒹' });
  });

  it('never throws on an invalid locale; falls back to the runtime default', () => {
    expect(() => tokenize('Smooth reading', { locale: 'not a locale!!' })).not.toThrow();
    expect(toHtml('Smooth reading', { locale: 'not a locale!!' })).toBe(
      '<b>Smo</b>oth <b>read</b>ing',
    );
  });

  it('never throws when Intl.Segmenter exists but its constructor fails', () => {
    Object.defineProperty(Intl, 'Segmenter', {
      value: function Broken() {
        throw new TypeError('unsupported');
      },
      configurable: true,
      writable: true,
    });
    expect(usesIntlSegmenter()).toBe(true);
    // A locale not seen before, so the cache cannot satisfy the request.
    expect(toHtml('Smooth reading', { locale: 'de-x-broken' })).toBe(
      '<b>Smo</b>oth <b>read</b>ing',
    );
  });

  it('applies the uniform rules to CJK runs under the fallback', () => {
    removeSegmenter();
    // One 5-character run -> prefix 3.
    expect(toHtml('我喜欢阅读。')).toBe('<b>我喜欢</b>阅读。');
  });
});
