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

/**
 * SPEC §3 fallback tokenizer: apostrophes join, hyphens split, and a word never
 * starts with a combining mark — a mark after a separator (the variation
 * selector of ❤️, say) belongs to that separator, as in ICU (UAX #29 WB4).
 */
const WORD_RE = /[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*/gu;

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

/** Hangul jamo classes (UAX #29 GB6–GB8); `[가-힣]` are the LV/LVT syllables. */
const HANGUL_L = '[\\u1100-\\u115F\\uA960-\\uA97C]';
const HANGUL_V = '[\\u1160-\\u11A7\\uD7B0-\\uD7C6]';
const HANGUL_T = '[\\u11A8-\\u11FF\\uD7CB-\\uD7FB]';
const HANGUL_SEQ = `(?:${HANGUL_L}*(?:${HANGUL_V}+|[\\uAC00-\\uD7A3]${HANGUL_V}*)${HANGUL_T}*|${HANGUL_L}+|${HANGUL_T}+)`;

/**
 * UAX #29 GB9c (Unicode 15.1): the Indic_Conjunct_Break=Linker viramas and the
 * Indic_Conjunct_Break=Consonant letters of Devanagari, Bengali, Gujarati,
 * Oriya, Telugu and Malayalam. `consonant (marks* linker marks* consonant)+`
 * is one cluster, so a conjunct such as क्ष is never split.
 */
const INDIC_LINKER = '[\\u094D\\u09CD\\u0ACD\\u0B4D\\u0C4D\\u0D4D]';
const INDIC_CONSONANT =
  '[\\u0915-\\u0939\\u0958-\\u095F\\u0978-\\u097F' + // Devanagari
  '\\u0995-\\u09A8\\u09AA-\\u09B0\\u09B2\\u09B6-\\u09B9\\u09DC-\\u09DD\\u09DF\\u09F0-\\u09F1' + // Bengali
  '\\u0A95-\\u0AA8\\u0AAA-\\u0AB0\\u0AB2-\\u0AB3\\u0AB5-\\u0AB9\\u0AF9' + // Gujarati
  '\\u0B15-\\u0B28\\u0B2A-\\u0B30\\u0B32-\\u0B33\\u0B35-\\u0B39\\u0B5C-\\u0B5D\\u0B5F\\u0B71' + // Oriya
  '\\u0C15-\\u0C28\\u0C2A-\\u0C39\\u0C58-\\u0C5A' + // Telugu
  '\\u0D15-\\u0D3A]'; // Malayalam
const INDIC_SEQ = `${INDIC_CONSONANT}(?:[\\p{M}\\u200D]*${INDIC_LINKER}[\\p{M}\\u200D]*${INDIC_CONSONANT})+`;

/**
 * SPEC §3 fallback grapheme clustering, identical to the Python port: a code
 * point plus any following combining marks (`\p{M}`, which includes variation
 * selectors), a ZWJ joins the next code point, Hangul jamo sequences compose
 * into syllables, Indic conjuncts of the Unicode 15.1 GB9c scripts link, and
 * CR LF is one cluster. Regional-indicator pairs are not composed, but they
 * cannot occur inside a word token produced by {@link WORD_RE}.
 */
const GRAPHEME_RE = new RegExp(`\\r\\n|(?:${HANGUL_SEQ}|${INDIC_SEQ}|.)(?:\\p{M}|\\u200D.?)*`, 'gsu');

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
