/**
 * Public option and token types for `@smooth-reading/core`.
 *
 * See `docs/SPEC.md` §4 — this file is the TypeScript rendering of that contract.
 */

/** Fixation strength: 1 (weakest) … 5 (strongest). */
export type Fixation = 1 | 2 | 3 | 4 | 5;

/**
 * Options that influence *which* characters of a word are emphasised.
 * They are shared by every entry point (`tokenize`, `toHtml`, `applyToElement`,
 * `createTransformStream`).
 *
 * @example
 * ```ts
 * tokenize('Smooth reading', { fixation: 4, saccade: 2 });
 * ```
 */
export interface SmoothOptions {
  /** Fixation strength, 1–5. Default `3`. */
  fixation?: Fixation | undefined;
  /** Emphasise every `saccade`-th word. Integer >= 1. Default `1`. */
  saccade?: number | undefined;
  /** Words with fewer grapheme clusters than this get no fixation. Default `1`. */
  minWordLength?: number | undefined;
  /** Emphasise words made entirely of digits. Default `false`. */
  emphasizeNumbers?: boolean | undefined;
  /** BCP-47 locale handed to `Intl.Segmenter`. Default `undefined` (runtime default). */
  locale?: string | undefined;
  /** Replace the fixation-length algorithm entirely (see {@link FixationLengthFn}). */
  fixationLength?: FixationLengthFn | undefined;
}

/**
 * A fully resolved set of {@link SmoothOptions}: every option has a value.
 * This is what a custom {@link FixationLengthFn} receives, and the type of
 * {@link defaults}.
 *
 * `fixationLength` is `undefined` unless the caller supplied an override; the
 * built-in algorithm is exported separately as {@link fixationLength}.
 */
export interface ResolvedSmoothOptions {
  fixation: Fixation;
  saccade: number;
  minWordLength: number;
  emphasizeNumbers: boolean;
  locale: string | undefined;
  fixationLength: FixationLengthFn | undefined;
}

/**
 * Signature of a custom fixation-length algorithm (SPEC §2).
 *
 * The return value is truncated to an integer and clamped to `0…graphemes`;
 * `0` means "no fixation".
 *
 * @example
 * ```ts
 * const half: FixationLengthFn = (_word, graphemes) => Math.ceil(graphemes / 2);
 * toHtml('reading', { fixationLength: half }); // '<b>read</b>ing'
 * ```
 */
export type FixationLengthFn = (
  word: string,
  graphemes: number,
  opts: ResolvedSmoothOptions,
) => number;

/** A word token: a maximal run of letters/digits/marks, apostrophes joining. */
export interface WordToken {
  readonly type: 'word';
  /** The whole word, exactly as it appeared in the input. */
  readonly text: string;
  /** Number of *grapheme clusters* that are emphasised. `0` means "no fixation". */
  readonly fixation: number;
  /** The emphasised prefix (`""` when `fixation` is `0`). */
  readonly fixationText: string;
  /** Everything after the prefix; `fixationText + restText === text`. */
  readonly restText: string;
}

/** Anything that is not a word: whitespace, punctuation, symbols. */
export interface SeparatorToken {
  readonly type: 'separator';
  readonly text: string;
}

/**
 * One piece of the input. Concatenating `token.text` over all tokens gives the
 * input back unchanged.
 */
export type Token = WordToken | SeparatorToken;

/**
 * Options shared by {@link toHtml} and {@link applyToElement}: how the
 * emphasis is rendered and which elements are left alone.
 */
export interface MarkupOptions extends SmoothOptions {
  /** Element name used for the fixation prefix. Default `"b"`. */
  tag?: string | undefined;
  /** `class` attribute for the fixation element. Default `undefined` → no attribute. */
  className?: string | undefined;
  /** Element name wrapped around the rest of the word. Default `undefined` → plain text. */
  restTag?: string | undefined;
  /** `class` attribute for the rest element. */
  restClassName?: string | undefined;
  /**
   * Elements whose text content is left completely untouched.
   * Default {@link defaultSkipTags}; passing your own list *replaces* it.
   */
  skipTags?: string[] | undefined;
}

/**
 * Options for {@link toHtml} and {@link createTransformStream}.
 *
 * @example
 * ```ts
 * toHtml(text, { tag: 'span', className: 'sr-fixation', ignoreHtmlTags: false });
 * ```
 */
export interface HtmlOptions extends MarkupOptions {
  /**
   * Treat the input as HTML: tags and character references (`&amp;`) pass
   * through verbatim, and `tag`/`restTag` join `skipTags`. Default `true`.
   * With `false` the input is plain text and every `<`, `>`, `&`, `"` is escaped.
   */
  ignoreHtmlTags?: boolean | undefined;
}

/**
 * Options for {@link applyToElement}.
 *
 * @example
 * ```ts
 * applyToElement(article, { fixation: 4, skipSelector: '.no-smooth' });
 * ```
 */
export interface DomOptions extends MarkupOptions {
  /** CSS selector; matching elements and their whole subtrees are skipped. */
  skipSelector?: string | undefined;
}
