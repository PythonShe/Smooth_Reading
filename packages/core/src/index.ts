/**
 * `@smooth-reading/core` — guided fixation reading.
 *
 * The implementation follows `docs/SPEC.md`, which is shared by every port, so
 * the output is byte-identical across languages for the fixtures in
 * `fixtures/common`.
 */

export { defaults, defaultSkipTags, defaultTag } from './defaults.js';
export { fixationLength, isNumeric, roundHalfUpRatio } from './fixation.js';
export { escapeHtml, toHtml } from './html.js';
export { tokenize } from './tokenize.js';
export { applyToElement } from './dom.js';
export { createTransformStream } from './stream.js';
export { usesIntlSegmenter, WORD_RE } from './segment.js';

export type {
  DomOptions,
  Fixation,
  FixationLengthFn,
  HtmlOptions,
  ResolvedSmoothOptions,
  SeparatorToken,
  SmoothOptions,
  Token,
  WordToken,
} from './types.js';
