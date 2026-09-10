import { resolveRenderOptions, type ResolvedRenderOptions } from './defaults.js';
import { createState, tokenizeWithState, type TokenizeState } from './tokenize.js';
import type { DomOptions } from './types.js';

/** `NodeFilter.SHOW_TEXT`, inlined so the module can be imported anywhere. */
const SHOW_TEXT = 0x4;

/**
 * Every node this module has inserted. A second pass walks over them without
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
  skip: Set<string>,
  skipSelector: string | undefined,
): boolean {
  if (produced.has(node)) return true;
  let current: Element | null =
    node.nodeType === 1 ? (node as Element) : node.parentElement;
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
  opts: ResolvedRenderOptions,
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
 * Emphasise every text node below `root`, in place.
 *
 * Each text node is processed independently, so words that a browser has split
 * across inline elements (`smo<i>oth</i>`) are simply treated as the separate
 * runs they are — no element is ever moved, merged or re-parented.
 *
 * Elements listed in `skipTags`, elements matching `skipSelector`, and elements
 * this function created itself are left alone, which makes repeated calls safe:
 * nothing is ever wrapped twice.
 *
 * @returns a `restore()` function that puts the original text nodes back.
 */
export function applyToElement(root: Element, options?: DomOptions): () => void {
  const opts = resolveRenderOptions(options);
  const skipSelector = options?.skipSelector;
  const skip = new Set<string>(opts.skipTags.map((name) => name.toLowerCase()));
  skip.add(opts.tag.toLowerCase());

  const doc = root.ownerDocument;
  const state = createState();
  const walker = doc.createTreeWalker(root, SHOW_TEXT);

  const targets: Text[] = [];
  for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
    const text = node as Text;
    if (text.data === '') continue;
    if (isSkipped(text, root, skip, skipSelector)) continue;
    targets.push(text);
  }

  const replacements: Replacement[] = [];
  for (const original of targets) {
    const parent = original.parentNode;
    if (!parent) continue;
    const nodes = buildNodes(doc, original.data, opts, state);
    // Nothing to emphasise (pure whitespace, or every word skipped): leave the
    // original node untouched so `restore()` stays as cheap as possible.
    if (nodes.length === 1 && nodes[0]?.nodeType === 3) continue;

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
      const record = replacements[i];
      if (!record) continue;
      const first = record.inserted[0];
      if (!first || first.parentNode !== record.parent) continue;
      record.parent.insertBefore(record.original, first);
      for (const node of record.inserted) {
        if (node.parentNode === record.parent) record.parent.removeChild(node);
      }
    }
  };
}
