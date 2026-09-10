/**
 * Segmentation primitives (SPEC §3).
 *
 * `Intl.Segmenter` is preferred when the runtime has it: it gives
 * dictionary-based word breaks for Chinese, Japanese, Khmer, Lao and Thai and
 * correct Unicode word-break rules everywhere else. When it is missing we fall
 * back to the regular expression the spec prescribes, which every non-JS port
 * also implements.
 */

/**
 * SPEC §3 fallback tokenizer. Mirrors ICU's default word-break rules for
 * Latin-like text: apostrophes join, hyphens split.
 */
export const WORD_RE = /[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*/gu;

const hasSegmenter =
  typeof Intl !== 'undefined' && typeof Intl.Segmenter === 'function';

/** `true` when this runtime segments with `Intl.Segmenter`. */
export const usesIntlSegmenter: boolean = hasSegmenter;

const wordSegmenters = new Map<string, Intl.Segmenter>();
const graphemeSegmenters = new Map<string, Intl.Segmenter>();

function getSegmenter(
  cache: Map<string, Intl.Segmenter>,
  locale: string | undefined,
  granularity: 'word' | 'grapheme',
): Intl.Segmenter {
  const key = locale ?? '';
  let segmenter = cache.get(key);
  if (!segmenter) {
    segmenter = new Intl.Segmenter(locale, { granularity });
    cache.set(key, segmenter);
  }
  return segmenter;
}

/** A raw segment: a slice of the input plus whether it is word-like. */
export interface RawSegment {
  readonly text: string;
  readonly isWord: boolean;
}

/**
 * Split `text` into word / non-word segments. Consecutive non-word segments are
 * merged into a single separator so that both code paths (segmenter and regex)
 * produce the same token stream.
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

  if (hasSegmenter) {
    const segmenter = getSegmenter(wordSegmenters, locale, 'word');
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
 * Split a string into grapheme clusters (SPEC §3). Falls back to code points,
 * which keeps surrogate pairs intact but may split combining marks on very old
 * runtimes.
 */
export function toGraphemes(text: string, locale: string | undefined): string[] {
  if (text === '') return [];
  if (hasSegmenter) {
    const segmenter = getSegmenter(graphemeSegmenters, locale, 'grapheme');
    const out: string[] = [];
    for (const segment of segmenter.segment(text)) out.push(segment.segment);
    return out;
  }
  return Array.from(text);
}

/** Number of user-perceived characters in `text`. */
export function countGraphemes(text: string, locale: string | undefined): number {
  return toGraphemes(text, locale).length;
}
