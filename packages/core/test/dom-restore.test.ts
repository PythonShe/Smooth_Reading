// @vitest-environment happy-dom
import { beforeEach, describe, expect, it } from 'vitest';
import { applyToElement, defaultSkipTags } from '../src/index.js';

function mount(html: string): HTMLElement {
  const root = document.createElement('div');
  root.innerHTML = html;
  document.body.appendChild(root);
  return root;
}

beforeEach(() => {
  document.body.innerHTML = '';
});

describe('applyToElement idempotence', () => {
  it('is a no-op on its own output, for any tag/restTag combination', () => {
    const options = { tag: 'span', className: 'sr-fixation', restTag: 'span', restClassName: 'sr-rest' };
    const root = mount('<p>Smooth <span>reading</span> works</p>');
    applyToElement(root, options);
    const once = root.innerHTML;
    applyToElement(root, options);
    applyToElement(root);
    expect(root.innerHTML).toBe(once);
  });

  it('re-applies after restore() with the same result', () => {
    const root = mount('Smooth reading');
    const restore = applyToElement(root);
    const once = root.innerHTML;
    restore();
    applyToElement(root);
    expect(root.innerHTML).toBe(once);
  });

  it('does not implicitly skip hand-written emphasis elements (use skipTags for that)', () => {
    const root = mount('<b>Smooth</b> reading');
    applyToElement(root);
    expect(root.innerHTML).toBe('<b><b>Smo</b>oth</b> <b>read</b>ing');

    const other = mount('<b>Smooth</b> reading');
    applyToElement(other, { skipTags: [...defaultSkipTags, 'b'] });
    expect(other.innerHTML).toBe('<b>Smooth</b> <b>read</b>ing');
  });
});

describe('restore() with a DOM mutated in between', () => {
  it('ignores inserted nodes the user removed and still restores the rest', () => {
    const root = mount('<p>Smooth reading</p>');
    const restore = applyToElement(root);
    root.querySelector('b')?.remove(); // drop "<b>Smo</b>"
    expect(() => restore()).not.toThrow();
    expect(root.innerHTML).toBe('<p>Smooth reading</p>');
  });

  it('does not reinsert when every inserted node is gone', () => {
    const root = mount('<p>Smooth</p><p>reading</p>');
    const restore = applyToElement(root);
    const first = root.querySelector('p') as HTMLElement;
    first.textContent = 'replaced';
    expect(() => restore()).not.toThrow();
    expect(root.innerHTML).toBe('<p>replaced</p><p>reading</p>');
  });

  it('does not throw when the whole subtree was replaced', () => {
    const root = mount('<p>Smooth reading</p>');
    const restore = applyToElement(root);
    root.innerHTML = '<em>new</em>';
    expect(() => restore()).not.toThrow();
    expect(root.innerHTML).toBe('<em>new</em>');
  });

  it('does not throw when the root was detached from the document', () => {
    const root = mount('Smooth reading');
    const restore = applyToElement(root);
    root.remove();
    expect(() => restore()).not.toThrow();
    expect(root.innerHTML).toBe('Smooth reading');
  });

  it('restores around content the user inserted next to the wrappers', () => {
    const root = mount('<p>Smooth</p>');
    const restore = applyToElement(root);
    const p = root.querySelector('p') as HTMLElement;
    p.appendChild(document.createTextNode('!'));
    restore();
    expect(root.innerHTML).toBe('<p>Smooth!</p>');
  });
});
