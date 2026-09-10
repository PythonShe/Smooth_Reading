import { resolveSmoothOptions } from './defaults.js';
import { fixationLength } from './fixation.js';
import { segmentWords, toGraphemes } from './segment.js';
import type { ResolvedSmoothOptions, SmoothOptions, Token, WordToken } from './types.js';

/**
 * Saccade bookkeeping. `toHtml` shares one counter across the whole input
 * (including text interrupted by HTML tags) and `createTransformStream` shares
 * one across every chunk, so that `saccade` indexing never restarts.
 */
export interface TokenizeState {
  wordIndex: number;
}

/**
 * Split `text` into words and separators and compute each word's fixation
 * prefix (SPEC §3, §4). Concatenating `token.text` gives `text` back.
 *
 * @example
 * ```ts
 * tokenize('Smooth reading');
 * // [ { type: 'word', text: 'Smooth', fixation: 3, fixationText: 'Smo', restText: 'oth' },
 * //   { type: 'separator', text: ' ' },
 * //   { type: 'word', text: 'reading', fixation: 4, fixationText: 'read', restText: 'ing' } ]
 * ```
 */
export function tokenize(text: string, options?: SmoothOptions): Token[] {
  return tokenizeWithState(text, resolveSmoothOptions(options), { wordIndex: 0 });
}

/** `tokenize`, but with an externally owned saccade counter. */
export function tokenizeWithState(
  text: string,
  opts: ResolvedSmoothOptions,
  state: TokenizeState,
): Token[] {
  const tokens: Token[] = [];
  for (const segment of segmentWords(text, opts.locale)) {
    tokens.push(
      segment.isWord
        ? makeWordToken(segment.text, opts, state)
        : { type: 'separator', text: segment.text },
    );
  }
  return tokens;
}

function makeWordToken(
  word: string,
  opts: ResolvedSmoothOptions,
  state: TokenizeState,
): WordToken {
  // Every word token consumes a saccade index, including numbers and words
  // that are too short to be emphasised (SPEC §4).
  const onSaccade = state.wordIndex % opts.saccade === 0;
  state.wordIndex += 1;
  if (!onSaccade) return plain(word);

  const graphemes = toGraphemes(word, opts.locale);
  const algorithm = opts.fixationLength ?? fixationLength;
  const requested = Math.trunc(algorithm(word, graphemes.length, opts));
  const fixation = Number.isFinite(requested)
    ? Math.min(Math.max(requested, 0), graphemes.length)
    : 0;
  if (fixation === 0) return plain(word);
  return {
    type: 'word',
    text: word,
    fixation,
    fixationText: graphemes.slice(0, fixation).join(''),
    restText: graphemes.slice(fixation).join(''),
  };
}

function plain(word: string): WordToken {
  return { type: 'word', text: word, fixation: 0, fixationText: '', restText: word };
}
