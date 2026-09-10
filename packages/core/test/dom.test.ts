// @vitest-environment happy-dom
import { beforeEach, describe, expect, it } from 'vitest';
import { applyToElement } from '../src/index.js';

function mount(html: string): HTMLElement {
  const root = document.createElement('div');
  root.innerHTML = html;
  document.body.appendChild(root);
  return root;
}

beforeEach(() => {
  document.body.innerHTML = '';
});

describe('applyToElement', () => {
  it('emphasises plain text and restores it exactly', () => {
    const root = mount('Smooth reading works.');
    const before = root.innerHTML;

    const restore = applyToElement(root);
    expect(root.innerHTML).toBe('<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.');

    restore();
    expect(root.innerHTML).toBe(before);
  });

  it('restore() is idempotent', () => {
    const root = mount('Smooth reading');
    const restore = applyToElement(root);
    restore();
    restore();
    expect(root.innerHTML).toBe('Smooth reading');
  });

  it('processes each text node independently when words are split by inline tags', () => {
    const root = mount('smo<i>oth</i> reading');
    const restore = applyToElement(root);
    // "smo" and "oth" are separate text nodes, so they are separate words.
    expect(root.innerHTML).toBe('<b>sm</b>o<i><b>ot</b>h</i> <b>read</b>ing');
    restore();
    expect(root.innerHTML).toBe('smo<i>oth</i> reading');
  });

  it('never touches text inside skipTags', () => {
    const root = mount('Try <code>reading()</code> now.');
    const code = root.querySelector('code');
    const codeText = code?.firstChild;

    const restore = applyToElement(root);
    expect(root.querySelector('code')?.innerHTML).toBe('reading()');
    // the very same text node object is still in place
    expect(root.querySelector('code')?.firstChild).toBe(codeText);
    restore();
    expect(root.innerHTML).toBe('Try <code>reading()</code> now.');
  });

  it('honours skipSelector', () => {
    const root = mount('<p class="raw">Smooth</p><p>reading</p>');
    const restore = applyToElement(root, { skipSelector: '.raw' });
    expect(root.innerHTML).toBe('<p class="raw">Smooth</p><p><b>read</b>ing</p>');
    restore();
    expect(root.innerHTML).toBe('<p class="raw">Smooth</p><p>reading</p>');
  });

  it('skips descendants of a skipped element, not just its direct text', () => {
    const root = mount('<div class="raw"><span><em>Smooth</em></span></div>');
    applyToElement(root, { skipSelector: '.raw' });
    expect(root.querySelectorAll('b')).toHaveLength(0);
  });

  it('does not double wrap when applied twice', () => {
    const root = mount('Smooth reading');
    const restoreA = applyToElement(root);
    const first = root.innerHTML;
    const restoreB = applyToElement(root);
    expect(root.innerHTML).toBe(first);
    expect(root.querySelectorAll('b b')).toHaveLength(0);

    restoreB();
    restoreA();
    expect(root.innerHTML).toBe('Smooth reading');
  });

  it('supports custom tags and class names', () => {
    const root = mount('Smooth');
    applyToElement(root, {
      tag: 'span',
      className: 'sr-fixation',
      restTag: 'span',
      restClassName: 'sr-rest',
    });
    expect(root.querySelector('.sr-fixation')?.textContent).toBe('Smo');
    expect(root.querySelector('.sr-rest')?.textContent).toBe('oth');
  });

  it('keeps saccade numbering across sibling text nodes', () => {
    const root = mount('<p>one two</p><p>three four</p>');
    applyToElement(root, { saccade: 2 });
    expect(root.innerHTML).toBe(
      '<p><b>on</b>e two</p><p><b>thr</b>ee four</p>',
    );
  });

  it('leaves whitespace-only and unemphasised text nodes alone', () => {
    const root = mount('<p>  </p><p>a</p>');
    const first = root.children[0]?.firstChild;
    applyToElement(root, { fixation: 1 });
    expect(root.children[0]?.firstChild).toBe(first);
    expect(root.innerHTML).toBe('<p>  </p><p>a</p>');
  });

  it('never inserts raw HTML (text is set as text, not markup)', () => {
    const root = mount('');
    root.textContent = 'a<script>alert(1)</script> reading';
    applyToElement(root);
    expect(root.querySelector('script')).toBeNull();
    expect(root.textContent).toBe('a<script>alert(1)</script> reading');
  });
});
