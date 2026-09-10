/**
 * Segmentation primitives (SPEC §3).
 *
 * `Intl.Segmenter` is preferred when the runtime has it: dictionary-based word
 * breaks for Chinese, Japanese and Thai and correct Unicode word-break rules
 * everywhere else. Otherwise we fall back to the regular expression the spec
 * prescribes, which every non-JS port also implements.
 *
 * Availability is checked at *call* time, never at module load, so the module
 * can be imported in any runtime (React Native/Hermes included) and never
 * throws even when `Intl` is partially implemented.
 */

/** SPEC §3 fallback tokenizer: apostrophes join, hyphens split. */
const WORD_RE = /[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*/gu;

type Granularity = 'word' | 'grapheme';

const cache: Record<Granularity, Map<string, Intl.Segmenter>> = {
  word: new Map(),
  grapheme: new Map(),
};

/**
 * Whether this runtime segments with `Intl.Segmenter` (evaluated now, not at
 * import time). When `false`, the SPEC §3 regex fallback is used for word
 * breaks and grapheme clusters are approximated as base + combining marks.
 *
 * @example
 * ```ts
 * if (!usesIntlSegmenter()) console.warn('CJK text will not be word-broken');
 * ```
 */
export function usesIntlSegmenter(): boolean {
  try {
    return typeof Intl !== 'undefined' && typeof Intl.Segmenter === 'function';
  } catch {
    return false;
  }
}

/**
 * A cached segmenter, or `null` when the runtime cannot provide one. An
 * invalid `locale` falls back to the runtime default rather than throwing.
 */
function getSegmenter(
  granularity: Granularity,
  locale: string | undefined,
): Intl.Segmenter | null {
  if (!usesIntlSegmenter()) return null;
  const key = locale ?? '';
  const map = cache[granularity];
  const cached = map.get(key);
  if (cached) return cached;
  let segmenter: Intl.Segmenter | null = null;
  try {
    segmenter = new Intl.Segmenter(locale, { granularity });
  } catch {
    try {
      segmenter = new Intl.Segmenter(undefined, { granularity });
    } catch {
      segmenter = null;
    }
  }
  if (segmenter) map.set(key, segmenter);
  return segmenter;
}

/** A raw segment: a slice of the input plus whether it is word-like. */
export interface RawSegment {
  readonly text: string;
  readonly isWord: boolean;
}

/**
 * Split `text` into word / non-word segments. Consecutive non-word segments are
 * merged into one separator so both code paths produce the same token stream.
 */
export function segmentWords(text: string, locale: string | undefined): RawSegment[] {
  if (text === '') return [];
  const out: RawSegment[] = [];
  const pushSeparator = (chunk: string): void => {
    if (chunk === '') return;
    const last = out[out.length - 1];
    if (last && !last.isWord) {
      out[out.length - 1] = { text: last.text + chunk, isWord: false };
    } else {
      out.push({ text: chunk, isWord: false });
    }
  };

  const segmenter = getSegmenter('word', locale);
  if (segmenter) {
    for (const segment of segmenter.segment(text)) {
      if (segment.isWordLike === true) {
        out.push({ text: segment.segment, isWord: true });
      } else {
        pushSeparator(segment.segment);
      }
    }
    return out;
  }

  WORD_RE.lastIndex = 0;
  let cursor = 0;
  for (let match = WORD_RE.exec(text); match !== null; match = WORD_RE.exec(text)) {
    if (match.index > cursor) pushSeparator(text.slice(cursor, match.index));
    out.push({ text: match[0], isWord: true });
    cursor = match.index + match[0].length;
  }
  if (cursor < text.length) pushSeparator(text.slice(cursor));
  return out;
}

/**
 * SPEC §3 fallback grapheme clustering, identical to the Python port: a code
 * point plus any following combining marks (`\p{M}`, which includes variation
 * selectors), a ZWJ joins the next code point, and CR LF is one cluster.
 * Regional-indicator pairs and Hangul jamo are not composed, but neither can
 * occur inside a word token produced by {@link WORD_RE}.
 */
const GRAPHEME_RE = /\r\n|.(?:\p{M}|\u200D.?)*/gsu;

/**
 * Split a string into grapheme clusters (SPEC §3): `Intl.Segmenter` when
 * available, otherwise the {@link GRAPHEME_RE} approximation.
 */
export function toGraphemes(text: string, locale: string | undefined): string[] {
  if (text === '') return [];
  const segmenter = getSegmenter('grapheme', locale);
  if (!segmenter) return text.match(GRAPHEME_RE) ?? [];
  const out: string[] = [];
  for (const segment of segmenter.segment(text)) out.push(segment.segment);
  return out;
}
