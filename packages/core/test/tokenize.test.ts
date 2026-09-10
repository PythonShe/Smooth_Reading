import { describe, expect, it } from 'vitest';
import { defaults, fixationLength, tokenize } from '../src/index.js';
import type { Token, WordToken } from '../src/index.js';

const words = (tokens: Token[]): WordToken[] =>
  tokens.filter((t): t is WordToken => t.type === 'word');

describe('tokenize', () => {
  it('returns nothing for an empty string', () => {
    expect(tokenize('')).toEqual([]);
  });

  it('splits words and separators and round-trips the input', () => {
    const tokens = tokenize('Smooth reading works.');
    expect(tokens.map((t) => t.type)).toEqual([
      'word',
      'separator',
      'word',
      'separator',
      'word',
      'separator',
    ]);
    expect(tokens.map((t) => t.text).join('')).toBe('Smooth reading works.');
  });

  it('always reassembles fixationText + restText into text', () => {
    for (const token of words(tokenize('Καλημέρα κόσμε, don’t stop 2024'))) {
      expect(token.fixationText + token.restText).toBe(token.text);
    }
  });

  it('computes the fixation prefix in graphemes', () => {
    const [word] = words(tokenize('reading'));
    expect(word).toEqual({
      type: 'word',
      text: 'reading',
      fixation: 4,
      fixationText: 'read',
      restText: 'ing',
    });
  });

  it('merges consecutive separators into one token', () => {
    const tokens = tokenize('hi ... there');
    expect(tokens.filter((t) => t.type === 'separator').map((t) => t.text)).toEqual([
      ' ... ',
    ]);
  });

  it('treats a combining mark as part of its base grapheme', () => {
    const [word] = words(tokenize('naïve'));
    expect(word?.text).toBe('naïve');
    expect(word?.fixation).toBe(3);
    expect(word?.fixationText).toBe('naï');
    expect(word?.restText).toBe('ve');
  });

  it('does not emphasise pure numbers by default', () => {
    const [word] = words(tokenize('2024'));
    expect(word?.fixation).toBe(0);
    expect(word?.restText).toBe('2024');
  });

  it('emphasises numbers when asked', () => {
    const [word] = words(tokenize('2024', { emphasizeNumbers: true }));
    expect(word?.fixationText).toBe('20');
  });

  it('honours saccade over word tokens only', () => {
    const tokens = words(tokenize('one two three four', { saccade: 2 }));
    expect(tokens.map((t) => t.fixation > 0)).toEqual([true, false, true, false]);
  });

  it('normalises a nonsensical saccade to 1', () => {
    const tokens = words(tokenize('one two', { saccade: 0 }));
    expect(tokens.map((t) => t.fixation > 0)).toEqual([true, true]);
  });

  it('honours minWordLength', () => {
    const tokens = words(tokenize('I am big', { minWordLength: 3 }));
    expect(tokens.map((t) => t.fixation)).toEqual([0, 0, 2]);
  });

  it('accepts a fixationLength override and clamps its result', () => {
    const tokens = words(
      tokenize('reading', { fixationLength: () => 999 }),
    );
    expect(tokens[0]?.fixationText).toBe('reading');
    expect(tokens[0]?.restText).toBe('');
  });

  it('passes resolved options to the override', () => {
    let seen: unknown;
    tokenize('reading', {
      fixation: 5,
      fixationLength: (word, graphemes, opts) => {
        seen = { word, graphemes, fixation: opts.fixation, saccade: opts.saccade };
        return 1;
      },
    });
    expect(seen).toEqual({
      word: 'reading',
      graphemes: 7,
      fixation: 5,
      saccade: 1,
    });
  });
});

describe('defaults', () => {
  it('matches SPEC section 4', () => {
    expect(defaults.fixation).toBe(3);
    expect(defaults.saccade).toBe(1);
    expect(defaults.minWordLength).toBe(1);
    expect(defaults.emphasizeNumbers).toBe(false);
    expect(defaults.locale).toBeUndefined();
    expect(defaults.fixationLength).toBe(fixationLength);
  });
});

describe('fixationLength', () => {
  const opts = (over: Partial<typeof defaults> = {}) => ({ ...defaults, ...over });

  it('reproduces the SPEC section 2 table at strength 3', () => {
    const table: Array<[string, number, number]> = [
      ['a', 1, 1],
      ['to', 2, 1],
      ['the', 3, 2],
      ['read', 4, 2],
      ['smooth', 6, 3],
      ['reading', 7, 4],
      ['2024', 4, 0],
      ['naïve', 5, 3],
    ];
    for (const [word, n, expected] of table) {
      expect(fixationLength(word, n, opts())).toBe(expected);
    }
  });

  it('rounds half up, never to even', () => {
    // n = 5, ratio 0.5 -> 2.5 -> 3 (banker's rounding would give 2)
    expect(fixationLength('works', 5, opts({ fixation: 3 }))).toBe(3);
    // n = 7, ratio 0.5 -> 3.5 -> 4
    expect(fixationLength('reading', 7, opts({ fixation: 3 }))).toBe(4);
  });

  it('never returns less than 1 or more than n for an eligible word', () => {
    for (const fixation of [1, 2, 3, 4, 5] as const) {
      for (let n = 2; n <= 40; n += 1) {
        const value = fixationLength('x'.repeat(n), n, opts({ fixation }));
        expect(value).toBeGreaterThanOrEqual(1);
        expect(value).toBeLessThanOrEqual(n);
      }
    }
  });

  it('emphasises a one-character word only from strength 3 up', () => {
    expect(fixationLength('a', 1, opts({ fixation: 1 }))).toBe(0);
    expect(fixationLength('a', 1, opts({ fixation: 2 }))).toBe(0);
    expect(fixationLength('a', 1, opts({ fixation: 3 }))).toBe(1);
    expect(fixationLength('a', 1, opts({ fixation: 5 }))).toBe(1);
  });

  it('skips digits before the single-character rule', () => {
    expect(fixationLength('7', 1, opts({ fixation: 5 }))).toBe(0);
    expect(fixationLength('7', 1, opts({ fixation: 5, emphasizeNumbers: true }))).toBe(1);
  });

  it('returns 0 for an empty word', () => {
    expect(fixationLength('', 0, opts())).toBe(0);
  });
});
