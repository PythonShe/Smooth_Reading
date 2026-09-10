import type { Fixation, ResolvedSmoothOptions } from './types.js';

/**
 * Fixation ratios from SPEC §2, expressed in *percent* so the whole
 * computation can be done in integer arithmetic. Floating point
 * `floor(n * 0.35 + 0.5)` is representation-dependent near .5 boundaries;
 * `floor((n * 35 + 50) / 100)` is exactly the same value and is reproducible
 * in every language a port might use.
 */
const RATIO_PERCENT: Readonly<Record<Fixation, number>> = {
  1: 20,
  2: 35,
  3: 50,
  4: 65,
  5: 80,
};

const ALL_DIGITS = /^\p{N}+$/u;

/** `true` when the word consists entirely of digits (SPEC §2 rule 3). */
export function isNumeric(word: string): boolean {
  return ALL_DIGITS.test(word);
}

/** `round_half_up(n * ratio)` from SPEC §2, in exact integer arithmetic. */
export function roundHalfUpRatio(graphemes: number, fixation: Fixation): number {
  const percent = RATIO_PERCENT[fixation] ?? RATIO_PERCENT[3];
  return Math.floor((graphemes * percent + 50) / 100);
}

/**
 * The default fixation-length algorithm (SPEC §2).
 *
 * Exported so that ports and adapters can reuse it, and so that a custom
 * `options.fixationLength` can delegate to it for the cases it does not care
 * about.
 *
 * @param word       the word, exactly as tokenized
 * @param graphemes  number of user-perceived characters in `word`
 * @param opts       fully resolved options
 * @returns how many *grapheme clusters* to emphasise (`0` = no fixation)
 */
export function fixationLength(
  word: string,
  graphemes: number,
  opts: ResolvedSmoothOptions,
): number {
  const n = graphemes;
  if (n <= 0) return 0;
  if (!opts.emphasizeNumbers && isNumeric(word)) return 0;
  if (n < opts.minWordLength) return 0;
  if (n === 1) return opts.fixation >= 3 ? 1 : 0;

  const raw = roundHalfUpRatio(n, opts.fixation);
  return Math.min(Math.max(raw, 1), n);
}
