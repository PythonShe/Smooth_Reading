import { resolveSmoothOptions } from './defaults.js';
import { segmentWords, toGraphemes } from './segment.js';
import type { ResolvedSmoothOptions, SmoothOptions, Token } from './types.js';

/**
 * Saccade bookkeeping. `toHtml` shares one counter across the whole input
 * (including text interrupted by HTML tags) and `createTransformStream` shares
 * one across every chunk, so that `saccade` indexing never restarts.
 */
export interface TokenizeState {
  wordIndex: number;
}

/** A fresh saccade counter. */
export function createState(): TokenizeState {
  return { wordIndex: 0 };
}

/**
 * Split `text` into words and separators and compute each word's fixation
 * prefix (SPEC §3, §4).
 */
export function tokenize(text: string, options?: SmoothOptions): Token[] {
  return tokenizeWithState(text, resolveSmoothOptions(options), createState());
}

/** `tokenize`, but with an externally owned saccade counter. */
export function tokenizeWithState(
  text: string,
  opts: ResolvedSmoothOptions,
  state: TokenizeState,
): Token[] {
  const tokens: Token[] = [];
  for (const segment of segmentWords(text, opts.locale)) {
    if (!segment.isWord) {
      tokens.push({ type: 'separator', text: segment.text });
      continue;
    }
    tokens.push(makeWordToken(segment.text, opts, state));
  }
  return tokens;
}

function makeWordToken(
  word: string,
  opts: ResolvedSmoothOptions,
  state: TokenizeState,
): Token {
  const graphemes = toGraphemes(word, opts.locale);
  // Saccade counts *every* word token, including numbers and words that are too
  // short to be emphasised (SPEC §4).
  const onSaccade = state.wordIndex % opts.saccade === 0;
  state.wordIndex += 1;

  if (!onSaccade) {
    return { type: 'word', text: word, fixation: 0, fixationText: '', restText: word };
  }

  const requested = opts.fixationLength(word, graphemes.length, opts);
  const fixation = clamp(Math.trunc(requested), 0, graphemes.length);
  if (fixation === 0) {
    return { type: 'word', text: word, fixation: 0, fixationText: '', restText: word };
  }
  return {
    type: 'word',
    text: word,
    fixation,
    fixationText: graphemes.slice(0, fixation).join(''),
    restText: graphemes.slice(fixation).join(''),
  };
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(Math.max(value, min), max);
}
