import { describe, expect, it } from 'vitest';
import { escapeHtml, toHtml } from '../src/index.js';

describe('escapeHtml', () => {
  it('escapes the four characters SPEC section 4 lists', () => {
    expect(escapeHtml('a & b < c > d "e"')).toBe(
      'a &amp; b &lt; c &gt; d &quot;e&quot;',
    );
  });

  it("leaves everything else alone, including '", () => {
    expect(escapeHtml("it's naïve 我")).toBe("it's naïve 我");
  });
});

describe('toHtml', () => {
  it('is deterministic', () => {
    const input = 'Smooth reading works, and 2024 is fine.';
    expect(toHtml(input)).toBe(toHtml(input));
  });

  it('emits no markup when nothing is emphasised', () => {
    expect(toHtml('a e', { fixation: 1 })).toBe('a e');
  });

  it('never nests the emphasis tag when re-run on its own output', () => {
    const once = toHtml('Smooth reading works.');
    const twice = toHtml(once);
    expect(twice).not.toMatch(/<b[^>]*><b/);
    expect(twice).toContain('<b>Smo</b>');
    expect(twice).toContain('<b>read</b>');
  });

  it('leaves the text of already-emphasised elements untouched', () => {
    expect(toHtml('<b>Smooth</b> reading')).toBe('<b>Smooth</b> <b>read</b>ing');
  });

  it('skips the emphasis tag even when it is customised', () => {
    expect(
      toHtml('<mark>Smooth</mark> reading', { tag: 'mark' }),
    ).toBe('<mark>Smooth</mark> <mark>read</mark>ing');
  });

  it('handles nested skip elements', () => {
    expect(toHtml('a <pre>x <pre>y</pre> z</pre> reading')).toBe(
      '<b>a</b> <pre>x <pre>y</pre> z</pre> <b>read</b>ing',
    );
  });

  it('does not escape attribute values of passed-through tags', () => {
    expect(toHtml('<a href="?a=1&b=2" title="hi">reading</a>')).toBe(
      '<a href="?a=1&b=2" title="hi"><b>read</b>ing</a>',
    );
  });

  it('treats a self-closing skip tag as not opening a skip region', () => {
    expect(toHtml('reading <code/> works')).toBe(
      '<b>read</b>ing <code/> <b>wor</b>ks',
    );
  });

  it('escapes stray angle brackets when ignoreHtmlTags is false', () => {
    expect(toHtml('5 < 6', { ignoreHtmlTags: false })).toBe('5 &lt; 6');
  });

  it('escapes a class name', () => {
    expect(toHtml('reading', { className: 'a"b' })).toBe(
      '<b class="a&quot;b">read</b>ing',
    );
  });

  it('emits no rest element when the whole word is emphasised', () => {
    expect(toHtml('a', { fixation: 3, restTag: 'i' })).toBe('<b>a</b>');
  });
});
