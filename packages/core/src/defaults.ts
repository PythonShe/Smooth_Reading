import type { MarkupOptions, ResolvedSmoothOptions, SmoothOptions } from './types.js';

/**
 * The resolved default options (SPEC §4). Frozen; spread it to build a
 * {@link ResolvedSmoothOptions} by hand, e.g. when calling
 * {@link fixationLength} directly.
 *
 * @example
 * ```ts
 * fixationLength('reading', 7, { ...defaults, fixation: 5 }); // 6
 * ```
 */
export const defaults: Readonly<ResolvedSmoothOptions> = Object.freeze({
  fixation: 3,
  saccade: 1,
  minWordLength: 1,
  emphasizeNumbers: false,
  locale: undefined,
  fixationLength: undefined,
});

/**
 * Elements whose text content is never rewritten unless `skipTags` is
 * overridden (SPEC §4). Spread it to extend rather than replace the list.
 *
 * @example
 * ```ts
 * toHtml(html, { skipTags: [...defaultSkipTags, 'blockquote'] });
 * ```
 */
export const defaultSkipTags: readonly string[] = Object.freeze([
  'code',
  'pre',
  'script',
  'style',
  'kbd',
  'samp',
  'textarea',
]);

const DEFAULT_TAG = 'b';

/** @internal */
export function resolveSmoothOptions(options?: SmoothOptions): ResolvedSmoothOptions {
  if (!options) return defaults;
  return {
    fixation: options.fixation ?? defaults.fixation,
    saccade: normalizeSaccade(options.saccade),
    minWordLength: options.minWordLength ?? defaults.minWordLength,
    emphasizeNumbers: options.emphasizeNumbers ?? defaults.emphasizeNumbers,
    locale: options.locale ?? defaults.locale,
    fixationLength: options.fixationLength ?? defaults.fixationLength,
  };
}

function normalizeSaccade(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) return defaults.saccade;
  return Math.max(1, Math.floor(value));
}

/** @internal Fully resolved {@link MarkupOptions}. */
export interface ResolvedMarkupOptions extends ResolvedSmoothOptions {
  tag: string;
  className: string | undefined;
  restTag: string | undefined;
  restClassName: string | undefined;
  skipTags: readonly string[];
}

/** @internal */
export function resolveMarkupOptions(options?: MarkupOptions): ResolvedMarkupOptions {
  return {
    ...resolveSmoothOptions(options),
    tag: options?.tag ?? DEFAULT_TAG,
    className: options?.className,
    restTag: options?.restTag,
    restClassName: options?.restClassName,
    skipTags: options?.skipTags ?? defaultSkipTags,
  };
}
