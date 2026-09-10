import { describe, expect, it } from 'vitest';
import { defaults, fixationLength, toHtml, tokenize } from '../src/index.js';

describe('SPEC section 4: entities', () => {
  it('passes named, decimal and hex references through and treats them as boundaries', () => {
    expect(toHtml('a&amp;b &#169; c&#x27;d')).toBe(
      '<b>a</b>&amp;<b>b</b> &#169; <b>c</b>&#x27;<b>d</b>',
    );
  });

  it('escapes a bare ampersand and near-misses', () => {
    expect(toHtml('& &amp &#; &#xZ; &;')).toBe('&amp; &amp;<b>am</b>p &amp;#; &amp;#<b>x</b>Z; &amp;;');
  });

  it('escapes every ampersand when ignoreHtmlTags is false', () => {
    expect(toHtml('&amp; &#169;', { ignoreHtmlTags: false })).toBe(
      '&amp;<b>am</b>p; &amp;#169;',
    );
  });

  it('leaves references inside skipped elements alone', () => {
    expect(toHtml('<code>&amp; & <</code> x')).toBe('<code>&amp; & <</code> <b>x</b>');
  });
});

describe('SPEC section 4: angle brackets', () => {
  it('only starts markup before a letter, "/", "!" or "?"', () => {
    expect(toHtml('<p>x</p><!doctype html><?pi?>')).toBe('<p><b>x</b></p><!doctype html><?pi?>');
    expect(toHtml('a < b <3 <-x <=y < <\n')).toBe(
      '<b>a</b> &lt; <b>b</b> &lt;3 &lt;-<b>x</b> &lt;=<b>y</b> &lt; &lt;\n',
    );
  });

  it('treats an unterminated tag as text', () => {
    expect(toHtml('x <b y')).toBe('<b>x</b> &lt;<b>b</b> <b>y</b>');
  });

  it('keeps a ">" inside a comment or CDATA section inside the block', () => {
    expect(toHtml('<!-- a > b --> reading')).toBe('<!-- a > b --> <b>read</b>ing');
    expect(toHtml('<![CDATA[ a > b ]]> reading')).toBe('<![CDATA[ a > b ]]> <b>read</b>ing');
  });

  it('degrades an unterminated comment to a declaration ending at the first ">"', () => {
    expect(toHtml('<!-- a > b reading')).toBe('<!-- a > <b>b</b> <b>read</b>ing');
  });

  it('does not let a tag inside a skipped element close the skip region', () => {
    expect(toHtml('<pre>if (a < 3) <i>x</i></pre> reading')).toBe(
      '<pre>if (a < 3) <i>x</i></pre> <b>read</b>ing',
    );
  });

  it('skips restTag as well as tag', () => {
    expect(toHtml('<i>keep</i> reading', { restTag: 'i' })).toBe(
      '<i>keep</i> <b>read</b><i>ing</i>',
    );
  });

  it('matches tag names case-insensitively', () => {
    expect(toHtml('<CODE>x</Code> reading')).toBe('<CODE>x</Code> <b>read</b>ing');
  });
});

describe('SPEC section 2: digits', () => {
  it('suppresses only decimal digits (Nd), not other numerics', () => {
    expect(fixationLength('42', 2, defaults)).toBe(0);
    expect(fixationLength('٤٢', 2, defaults)).toBe(0);
    expect(fixationLength('３', 1, defaults)).toBe(0);
    expect(fixationLength('½', 1, defaults)).toBe(1);
    expect(fixationLength('Ⅻ', 1, defaults)).toBe(1);
    expect(fixationLength('4th', 3, defaults)).toBe(2);
  });

  it('emphasises a letter-number word through the full pipeline', () => {
    expect(toHtml('Ⅻ ٤٢')).toBe('<b>Ⅻ</b> ٤٢');
    expect(tokenize('Ⅻ')[0]).toMatchObject({ type: 'word', fixation: 1 });
  });
});

describe('SPEC section 2: rule ordering', () => {
  it('applies suppression before the single-character rule', () => {
    expect(fixationLength('7', 1, { ...defaults, fixation: 5 })).toBe(0);
    expect(fixationLength('a', 1, { ...defaults, minWordLength: 2, fixation: 5 })).toBe(0);
  });

  it('uses integer round-half-up: floor((n * percent + 50) / 100)', () => {
    // n=6 at strength 2: 6*35 = 210 -> (210+50)/100 = 2.6 -> 2
    expect(fixationLength('abcdef', 6, { ...defaults, fixation: 2 })).toBe(2);
    // n=10 at strength 2: 350+50 = 400 -> 4 (3.5 rounds up)
    expect(fixationLength('abcdefghij', 10, { ...defaults, fixation: 2 })).toBe(4);
    // n=2 at strength 1: 40+50 -> 0.9 -> 0, clamped to 1
    expect(fixationLength('ab', 2, { ...defaults, fixation: 1 })).toBe(1);
  });
});
