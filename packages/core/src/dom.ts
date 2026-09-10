import { resolveMarkupOptions, type ResolvedMarkupOptions } from './defaults.js';
import { tokenizeWithState, type TokenizeState } from './tokenize.js';
import type { DomOptions } from './types.js';

/** `NodeFilter.SHOW_TEXT`, inlined so the module can be imported anywhere. */
const SHOW_TEXT = 0x4;
const ELEMENT_NODE = 1;
const TEXT_NODE = 3;

/**
 * Every node this module has inserted. A later pass walks over them without
 * touching them, so `applyToElement` is idempotent and leaves no marker
 * attributes behind in the user's DOM.
 */
const produced = new WeakSet<Node>();

interface Replacement {
  parent: Node;
  original: Text;
  inserted: Node[];
}

function isSkipped(
  node: Node,
  root: Element,
  skip: ReadonlySet<string>,
  skipSelector: string | undefined,
): boolean {
  if (produced.has(node)) return true;
  let current: Element | null =
    node.nodeType === ELEMENT_NODE ? (node as Element) : node.parentElement;
  while (current) {
    if (produced.has(current)) return true;
    if (skip.has(current.tagName.toLowerCase())) return true;
    if (skipSelector !== undefined && current.matches(skipSelector)) return true;
    if (current === root) return false;
    current = current.parentElement;
  }
  return false;
}

function makeElement(
  doc: Document,
  name: string,
  className: string | undefined,
  text: string,
): Element {
  const el = doc.createElement(name);
  if (className !== undefined) el.setAttribute('class', className);
  el.appendChild(doc.createTextNode(text));
  produced.add(el);
  return el;
}

function buildNodes(
  doc: Document,
  text: string,
  opts: ResolvedMarkupOptions,
  state: TokenizeState,
): Node[] {
  const nodes: Node[] = [];
  const pushText = (value: string): void => {
    const node = doc.createTextNode(value);
    produced.add(node);
    nodes.push(node);
  };
  for (const token of tokenizeWithState(text, opts, state)) {
    if (token.type === 'separator' || token.fixation === 0) {
      pushText(token.text);
      continue;
    }
    nodes.push(makeElement(doc, opts.tag, opts.className, token.fixationText));
    if (token.restText === '') continue;
    if (opts.restTag === undefined) {
      pushText(token.restText);
    } else {
      nodes.push(makeElement(doc, opts.restTag, opts.restClassName, token.restText));
    }
  }
  return nodes;
}

/**
 * Emphasise every text node below `root`, in place. Browser only.
 *
 * Each text node is processed independently, so a word a browser has split
 * across inline elements (`smo<i>oth</i>`) is treated as the separate runs it
 * is — no element is ever moved, merged or re-parented. Text is inserted as
 * text nodes, never as markup.
 *
 * Elements listed in `skipTags`, elements matching `skipSelector`, and nodes
 * this function created itself are left alone, which makes repeated calls
 * safe: nothing is ever wrapped twice, and no marker attributes are added.
 * Unlike `toHtml`, existing `tag`/`restTag` elements are *not* implicitly
 * skipped (that would silence every `<span>` on a page when `tag: "span"`);
 * add them to `skipTags` if you want hand-written `<b>` left alone.
 *
 * @returns `restore()`, which puts the original text nodes back. It tolerates
 * a DOM that was modified in the meantime: inserted nodes that were removed
 * are ignored, and if none of a replacement's nodes are still in place the
 * original text node is not reinserted. Calling it twice is a no-op.
 *
 * @example
 * ```ts
 * const restore = applyToElement(document.querySelector('article')!, { fixation: 4 });
 * // later
 * restore();
 * ```
 */
export function applyToElement(root: Element, options?: DomOptions): () => void {
  const opts = resolveMarkupOptions(options);
  const skipSelector = options?.skipSelector;
  const skip = new Set(opts.skipTags.map((name) => name.toLowerCase()));

  const doc = root.ownerDocument;
  const state: TokenizeState = { wordIndex: 0 };
  const walker = doc.createTreeWalker(root, SHOW_TEXT);

  // Collect first: replacing nodes while the walker is live would confuse it.
  const targets: Text[] = [];
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    const text = node as Text;
    if (text.data !== '' && !isSkipped(text, root, skip, skipSelector)) targets.push(text);
  }

  const replacements: Replacement[] = [];
  for (const original of targets) {
    const parent = original.parentNode;
    if (!parent) continue;
    const nodes = buildNodes(doc, original.data, opts, state);
    // Nothing to emphasise (whitespace, or every word skipped): leave the
    // original node untouched so `restore()` stays as cheap as possible.
    if (nodes.length === 1 && nodes[0]?.nodeType === TEXT_NODE) continue;

    const fragment = doc.createDocumentFragment();
    for (const child of nodes) fragment.appendChild(child);
    parent.replaceChild(fragment, original);
    replacements.push({ parent, original, inserted: nodes });
  }

  let restored = false;
  return function restore(): void {
    if (restored) return;
    restored = true;
    for (let i = replacements.length - 1; i >= 0; i -= 1) {
      const { parent, original, inserted } = replacements[i] as Replacement;
      const survivors = inserted.filter((node) => node.parentNode === parent);
      const first = survivors[0];
      if (first === undefined) continue; // user removed everything we inserted
      parent.insertBefore(original, first);
      for (const node of survivors) parent.removeChild(node);
    }
  };
}
