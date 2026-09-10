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

  it('composes decomposed Hangul jamo under the fallback (SPEC §3)', () => {
    removeSegmenter();
    const decomposed = '한글'.normalize('NFD'); // ᄒ ᅡ ᆫ ᄀ ᅳ ᆯ
    const [word] = tokenize(decomposed, { fixation: 1 });
    expect(word).toMatchObject({ fixation: 1, fixationText: '한'.normalize('NFD') });
    expect(toHtml(decomposed, { fixation: 1 })).toBe(`<b>${'한'.normalize('NFD')}</b>${'글'.normalize('NFD')}`);
  });

  it('keeps Indic conjuncts in one cluster under the fallback (SPEC §3, GB9c)', () => {
    removeSegmenter();
    // क्ष | त्रि | य — the fixation ends after a whole conjunct, never after a virama.
    expect(tokenize('क्षत्रिय')[0]).toMatchObject({ fixation: 2, fixationText: 'क्षत्रि', restText: 'य' });
    // Bengali: ক্ষ is one cluster; Tamil pulli is not a linker, so தமிழ் stays 3 clusters.
    expect(tokenize('ক্ষমা')[0]).toMatchObject({ fixation: 1, fixationText: 'ক্ষ' });
    expect(tokenize('தமிழ்')[0]).toMatchObject({ fixation: 2, fixationText: 'தமி' });
    // An independent vowel is not a consonant: no linking across उ.
    expect(tokenize('उम्र')[0]).toMatchObject({ fixation: 1, fixationText: 'उ', restText: 'म्र' });
  });

  it('applies the uniform rules to CJK runs under the fallback', () => {
    removeSegmenter();
    // One 5-character run -> prefix 3.
    expect(toHtml('我喜欢阅读。')).toBe('<b>我喜欢</b>阅读。');
  });

  describe('no-space-script run rule (SPEC §3)', () => {
    const words = (text: string): string[] =>
      tokenize(text).filter((t) => t.type === 'word').map((t) => t.text);

    it('splits a run from adjacent letters and digits of other scripts', () => {
      removeSegmenter();
      expect(words('iPhone手机')).toEqual(['iPhone', '手机']);
      expect(words('abcก')).toEqual(['abc', 'ก']);
      expect(words('日本語OKです')).toEqual(['日本語', 'OK', 'です']);
      expect(words('abc한글')).toEqual(['abc', '한글']);
      expect(words('2024年')).toEqual(['2024', '年']);
    });

    it('is one word per continuous run, whatever the run length', () => {
      removeSegmenter();
      expect(words('iPhone手机很好用')).toEqual(['iPhone', '手机很好用']);
      expect(words('ภาษาไทยง่าย')).toEqual(['ภาษาไทยง่าย']);
      expect(words('ພາສາລາວ')).toEqual(['ພາສາລາວ']);
      expect(words('မြန်မာ')).toEqual(['မြန်မာ']);
      expect(words('ខ្ញុំ')).toEqual(['ខ្ញុំ']);
    });

    it('keeps combining marks that follow a run character in the run', () => {
      removeSegmenter();
      expect(words('我́x')).toEqual(['我́', 'x']);
      expect(words('我́')).toEqual(['我́']);
      // A mark that follows no run character is part of the separator (WB4).
      expect(words('abcั')).toEqual(['abc']);
    });

    it('never lets an apostrophe join a run character to an ordinary word', () => {
      removeSegmenter();
      expect(words("don't")).toEqual(["don't"]);
      expect(words("it'手机")).toEqual(['it', '手机']);
      expect(words("手机'it")).toEqual(['手机', 'it']);
    });

    it('only counts run-table characters whose category is L, N or M', () => {
      removeSegmenter();
      // U+30FB Katakana middle dot is punctuation: a separator, not a run char.
      expect(words('ア・イ')).toEqual(['ア', 'イ']);
      // U+3007 ideographic zero and U+3005 iteration mark are letters/numbers.
      expect(words('〇〇')).toEqual(['〇〇']);
    });

    it('matches the Intl.Segmenter path on the shared run fixtures', () => {
      for (const input of ['iPhone手机', 'abc한글', 'OK한국어문장', '我́x']) {
        const icu = toHtml(input);
        removeSegmenter();
        expect(toHtml(input), input).toBe(icu);
        Object.defineProperty(Intl, 'Segmenter', {
          value: realSegmenter,
          configurable: true,
          writable: true,
        });
      }
    });
  });
});
