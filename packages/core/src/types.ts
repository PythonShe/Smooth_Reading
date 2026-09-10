/**
 * Public option and token types for `@smooth-reading/core`.
 *
 * See `docs/SPEC.md` §4 — this file is the TypeScript rendering of that contract.
 */

/** Fixation strength: 1 (weakest) … 5 (strongest). */
export type Fixation = 1 | 2 | 3 | 4 | 5;

/**
 * Options that influence *which* characters of a word are emphasised.
 * They are shared by every entry point (`tokenize`, `toHtml`, `applyToElement`).
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
  /** Replace the fixation-length algorithm entirely. */
  fixationLength?: FixationLengthFn | undefined;
}

/**
 * A fully resolved set of {@link SmoothOptions}: every option has a value.
 *
 * This is the `Required<SmoothOptions>` of SPEC §4, spelled out so that
 * `locale` can keep its "no locale, use the runtime default" `undefined`.
 */
export interface ResolvedSmoothOptions {
  fixation: Fixation;
  saccade: number;
  minWordLength: number;
  emphasizeNumbers: boolean;
  locale: string | undefined;
  fixationLength: FixationLengthFn;
}

/** Signature of a custom fixation-length algorithm (SPEC §2). */
export type FixationLengthFn = (
  word: string,
  graphemes: number,
  opts: ResolvedSmoothOptions,
) => number;

/** A word token (a maximal run of letters/digits/marks, apostrophes joining). */
export interface WordToken {
  readonly type: 'word';
  /** The whole word, exactly as it appeared in the input. */
  readonly text: string;
  /** Number of *grapheme clusters* that are emphasised. `0` means "no fixation". */
  readonly fixation: number;
  /** The emphasised prefix (may be `""`). */
  readonly fixationText: string;
  /** Everything after the prefix (may be `""`). */
  readonly restText: string;
}

/** Anything that is not a word: whitespace, punctuation, symbols, HTML tags. */
export interface SeparatorToken {
  readonly type: 'separator';
  readonly text: string;
}

export type Token = WordToken | SeparatorToken;

/** Options for {@link toHtml}. */
export interface HtmlOptions extends SmoothOptions {
  /** Element name used for the fixation prefix. Default `"b"`. */
  tag?: string | undefined;
  /** `class` attribute for the fixation element. Default `undefined` → no attribute. */
  className?: string | undefined;
  /** Element name wrapped around the rest of the word. Default `undefined` → plain text. */
  restTag?: string | undefined;
  /** `class` attribute for the rest element. */
  restClassName?: string | undefined;
  /** Pass `<...>` through verbatim instead of escaping it. Default `true`. */
  ignoreHtmlTags?: boolean | undefined;
  /** Elements whose text content is left completely untouched. */
  skipTags?: string[] | undefined;
}

/** Options for {@link applyToElement}. */
export interface DomOptions extends SmoothOptions {
  /** Element name used for the fixation prefix. Default `"b"`. */
  tag?: string | undefined;
  /** `class` attribute for the fixation element. */
  className?: string | undefined;
  /** Element name wrapped around the rest of the word. */
  restTag?: string | undefined;
  /** `class` attribute for the rest element. */
  restClassName?: string | undefined;
  /** Elements whose text content is left untouched. */
  skipTags?: string[] | undefined;
  /** Additional CSS selector; matching elements and their subtrees are skipped. */
  skipSelector?: string | undefined;
}
