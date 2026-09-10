import { fixationLength } from './fixation.js';
import type {
  DomOptions,
  HtmlOptions,
  ResolvedSmoothOptions,
  SmoothOptions,
} from './types.js';

/** Resolved defaults for the segmentation/fixation layer (SPEC §4). */
export const defaults: ResolvedSmoothOptions = Object.freeze({
  fixation: 3,
  saccade: 1,
  minWordLength: 1,
  emphasizeNumbers: false,
  locale: undefined,
  fixationLength,
}) as ResolvedSmoothOptions;

/** Elements whose text content is never rewritten (SPEC §4). */
export const defaultSkipTags: readonly string[] = Object.freeze([
  'code',
  'pre',
  'script',
  'style',
  'kbd',
  'samp',
  'textarea',
]);

/** Default element name for the fixation prefix. */
export const defaultTag = 'b';

export function resolveSmoothOptions(options?: SmoothOptions): ResolvedSmoothOptions {
  if (!options) return defaults;
  const fixation = options.fixation ?? defaults.fixation;
  const saccade = normalizeSaccade(options.saccade);
  return {
    fixation,
    saccade,
    minWordLength: options.minWordLength ?? defaults.minWordLength,
    emphasizeNumbers: options.emphasizeNumbers ?? defaults.emphasizeNumbers,
    locale: options.locale ?? defaults.locale,
    fixationLength: options.fixationLength ?? defaults.fixationLength,
  };
}

function normalizeSaccade(value: number | undefined): number {
  if (value === undefined) return defaults.saccade;
  if (!Number.isFinite(value)) return defaults.saccade;
  const n = Math.floor(value);
  return n >= 1 ? n : 1;
}

/** Shape shared by `toHtml` and `applyToElement` for building markup. */
export interface ResolvedRenderOptions extends ResolvedSmoothOptions {
  tag: string;
  className: string | undefined;
  restTag: string | undefined;
  restClassName: string | undefined;
  skipTags: readonly string[];
}

export function resolveRenderOptions(
  options?: HtmlOptions | DomOptions,
): ResolvedRenderOptions {
  return {
    ...resolveSmoothOptions(options),
    tag: options?.tag ?? defaultTag,
    className: options?.className,
    restTag: options?.restTag,
    restClassName: options?.restClassName,
    skipTags: options?.skipTags ?? defaultSkipTags,
  };
}
