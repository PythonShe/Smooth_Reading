import type { Fixation, ResolvedSmoothOptions } from './types.js';

/**
 * Fixation ratios from SPEC §2 in *percent*, so the whole computation is
 * integer arithmetic: `floor((n * percent + 50) / 100)` is exactly
 * `round_half_up(n * ratio)` and reproducible in every port.
 */
const RATIO_PERCENT: Readonly<Record<Fixation, number>> = {
  1: 20,
  2: 35,
  3: 50,
  4: 65,
  5: 80,
};

/** "Entirely digits" (SPEC §2 rule 1): decimal digits of any script, not ½ or Ⅻ. */
const ALL_DIGITS = /^\p{Nd}+$/u;

/**
 * The built-in fixation-length algorithm (SPEC §2): how many leading grapheme
 * clusters of `word` to emphasise, `0` meaning none.
 *
 * Exported so a custom `fixationLength` override can delegate to it for the
 * cases it does not care about.
 *
 * @param word       the word exactly as tokenized
 * @param graphemes  number of user-perceived characters in `word`
 * @param opts       fully resolved options (spread {@link defaults} to build one)
 *
 * @example
 * ```ts
 * fixationLength('reading', 7, defaults); // 4
 * ```
 */
export function fixationLength(
  word: string,
  graphemes: number,
  opts: ResolvedSmoothOptions,
): number {
  const n = graphemes;
  if (n <= 0) return 0;
  if (!opts.emphasizeNumbers && ALL_DIGITS.test(word)) return 0;
  if (n < opts.minWordLength) return 0;
  if (n === 1) return opts.fixation >= 3 ? 1 : 0;

  const percent = RATIO_PERCENT[opts.fixation] ?? RATIO_PERCENT[3];
  const raw = Math.floor((n * percent + 50) / 100);
  return Math.min(Math.max(raw, 1), n);
}
