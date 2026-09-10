/**
 * `@smooth-reading/core` — guided fixation reading.
 *
 * The implementation follows `docs/SPEC.md`, which is shared by every port, so
 * the output is byte-identical across languages for the fixtures in
 * `fixtures/common`.
 */

export { tokenize } from './tokenize.js';
export { toHtml } from './html.js';
export { applyToElement } from './dom.js';
export { createTransformStream } from './stream.js';
export { fixationLength } from './fixation.js';
export { defaults, defaultSkipTags } from './defaults.js';
export { usesIntlSegmenter } from './segment.js';

export type {
  DomOptions,
  Fixation,
  FixationLengthFn,
  HtmlOptions,
  MarkupOptions,
  ResolvedSmoothOptions,
  SeparatorToken,
  SmoothOptions,
  Token,
  WordToken,
} from './types.js';
