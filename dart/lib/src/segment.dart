/// A raw segment of the input: a slice of text plus whether it is a word.
final class Segment {
  /// Creates a segment.
  const Segment(this.text, {required this.isWord});

  /// The exact slice of the input.
  final String text;

  /// `true` for a word, `false` for a separator (whitespace, punctuation,
  /// emoji, markup).
  final bool isWord;

  @override
  bool operator ==(Object other) =>
      other is Segment && other.text == text && other.isWord == isWord;

  @override
  int get hashCode => Object.hash(text, isWord);

  @override
  String toString() => 'Segment(${isWord ? 'word' : 'separator'}: $text)';
}

/// Supplies word boundaries and grapheme clusters to the tokenizer (SPEC §3).
///
/// Dart has no ICU break iterator in its standard library, so the default
/// implementation, [SpecSegmenter], is the spec's regular-expression fallback.
/// It behaves exactly like the Python port: every space-separated script
/// matches the ICU-backed ports byte for byte, and a continuous run of
/// Chinese, Japanese or Thai text is one word.
///
/// Apps that need dictionary-based word breaks for those scripts can
/// implement this interface on top of a platform break iterator (for example
/// `android.icu.text.BreakIterator` or `enumerateSubstrings(.byWords)` over a
/// Flutter platform channel, or `Intl.Segmenter` through JS interop on the
/// web) and pass it as `SmoothOptions(segmenter: ...)`. The fixation
/// algorithm itself never changes; only the boundary source does.
///
/// Contract: the texts of the returned segments must concatenate back to the
/// input. Consecutive separators may be returned as one segment or several;
/// the tokenizer merges them.
abstract class Segmenter {
  /// Allows subclasses to have `const` constructors.
  const Segmenter();

  /// Splits [text] into word and separator segments.
  List<Segment> segmentWords(String text, String? locale);

  /// Splits [text] into extended grapheme clusters (user-perceived characters).
  List<String> graphemes(String text, String? locale);
}

// Inclusive code-point ranges of the scripts written without spaces (Han,
// Hiragana, Katakana, Hangul, Thai, Lao, Myanmar, Khmer): the SPEC §3 run
// table shared by every regex-fallback port. A character counts only when it
// is also a letter, number or mark, so the Katakana middle dot (U+30FB) stays
// punctuation.
const String _run = r'(?=[\p{L}\p{N}\p{M}])['
    r'\u0E00-\u0E7F' // Thai
    r'\u0E80-\u0EFF' // Lao
    r'\u1000-\u109F' // Myanmar
    r'\u1100-\u11FF' // Hangul Jamo
    r'\u1780-\u17FF' // Khmer
    r'\u3005-\u3007' // ideographic iteration mark, ideographic zero
    r'\u3041-\u30FF' // Hiragana, Katakana
    r'\u3130-\u318F' // Hangul Compatibility Jamo
    r'\u31F0-\u31FF' // Katakana Phonetic Extensions
    r'\u3400-\u4DBF' // CJK Extension A
    r'\u4E00-\u9FFF' // CJK Unified Ideographs
    r'\uA960-\uA97F' // Hangul Jamo Extended-A
    r'\uA9E0-\uA9FF' // Myanmar Extended-B
    r'\uAA60-\uAA7F' // Myanmar Extended-A
    r'\uAC00-\uD7A3' // Hangul Syllables
    r'\uD7B0-\uD7FF' // Hangul Jamo Extended-B
    r'\uF900-\uFAFF' // CJK Compatibility Ideographs
    r'\uFF66-\uFF9D' // halfwidth Katakana
    r'\uFFA0-\uFFDC' // halfwidth Hangul
    r'\u{20000}-\u{2EBEF}' // CJK Extensions B-F
    r'\u{2F800}-\u{2FA1F}' // CJK Compatibility Ideographs Supplement
    r'\u{30000}-\u{323AF}' // CJK Extensions G-H
    r']';

// `[\p{L}\p{N}\p{M}]` and `[\p{L}\p{N}]` minus the run characters above.
const String _wordChar = '(?:(?!$_run)[\\p{L}\\p{N}\\p{M}])';
const String _wordStart = '(?:(?!$_run)[\\p{L}\\p{N}])';

/// SPEC §3 fallback tokenizer, exactly as the Python port scans it. Two
/// kinds of word:
///
/// * a continuous run of no-space-script characters (combining marks stay
///   attached), one word per run, split from adjacent text of other scripts,
///   so `iPhone手机` is `iPhone` + `手机` just as ICU breaks it;
/// * otherwise the spec regex
///   `[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*`:
///   apostrophes join, hyphens split, and a word never starts with a
///   combining mark (a mark after a separator, such as the variation selector
///   of ❤️, belongs to that separator, as in UAX #29 WB4).
final RegExp _wordRe = RegExp(
  "$_run(?:$_run|\\p{M})*|$_wordStart$_wordChar*(?:['’]$_wordChar+)*",
  unicode: true,
);

// Hangul jamo classes (UAX #29 GB6–GB8); U+AC00–U+D7A3 are the LV/LVT
// syllables.
const String _hangulL = r'[\u1100-\u115F\uA960-\uA97C]';
const String _hangulV = r'[\u1160-\u11A7\uD7B0-\uD7C6]';
const String _hangulT = r'[\u11A8-\u11FF\uD7CB-\uD7FB]';
const String _hangulSeq = '(?:$_hangulL*(?:$_hangulV+|[\\uAC00-\\uD7A3]'
    '$_hangulV*)$_hangulT*|$_hangulL+|$_hangulT+)';

// UAX #29 GB9c (Unicode 15.1): the Indic_Conjunct_Break=Linker viramas and
// the Indic_Conjunct_Break=Consonant letters of Devanagari, Bengali,
// Gujarati, Oriya, Telugu and Malayalam. `consonant (marks* linker marks*
// consonant)+` is one cluster, so a conjunct such as क्ष is never split.
const String _indicLinker = r'[\u094D\u09CD\u0ACD\u0B4D\u0C4D\u0D4D]';
const String _indicConsonant = '['
    r'\u0915-\u0939\u0958-\u095F\u0978-\u097F' // Devanagari
    r'\u0995-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09DC-\u09DD\u09DF\u09F0-\u09F1' // Bengali
    r'\u0A95-\u0AA8\u0AAA-\u0AB0\u0AB2-\u0AB3\u0AB5-\u0AB9\u0AF9' // Gujarati
    r'\u0B15-\u0B28\u0B2A-\u0B30\u0B32-\u0B33\u0B35-\u0B39\u0B5C-\u0B5D\u0B5F\u0B71' // Oriya
    r'\u0C15-\u0C28\u0C2A-\u0C39\u0C58-\u0C5A' // Telugu
    r'\u0D15-\u0D3A' // Malayalam
    ']';
const String _indicSeq = '$_indicConsonant(?:[\\p{M}\\u200D]*$_indicLinker'
    '[\\p{M}\\u200D]*$_indicConsonant)+';

/// SPEC §3 fallback grapheme clustering, identical to the TypeScript and
/// Python fallbacks: a code point plus any following combining marks (`\p{M}`,
/// which includes variation selectors), a ZWJ joins the next code point,
/// Hangul jamo sequences compose into syllables, Indic conjuncts of the
/// Unicode 15.1 GB9c scripts link, and CR LF is one cluster. Regional
/// indicator pairs are not composed, but they cannot occur inside a word
/// token produced by [_wordRe].
final RegExp _graphemeRe = RegExp(
  '\\r\\n|(?:$_hangulSeq|$_indicSeq|.)(?:\\p{M}|\\u200D.?)*',
  unicode: true,
  dotAll: true,
);

/// The spec's regular-expression segmenter (SPEC §3, fallback segmentation).
///
/// This is the default [Segmenter]. It needs no platform support and produces
/// the same output as the Python port and the TypeScript port's non-ICU path.
final class SpecSegmenter extends Segmenter {
  /// Creates the segmenter. It has no state; `const SpecSegmenter()` is free.
  const SpecSegmenter();

  @override
  List<Segment> segmentWords(String text, String? locale) {
    if (text.isEmpty) return const [];
    final out = <Segment>[];
    var cursor = 0;
    for (final match in _wordRe.allMatches(text)) {
      if (match.start > cursor) {
        out.add(Segment(text.substring(cursor, match.start), isWord: false));
      }
      out.add(Segment(match[0]!, isWord: true));
      cursor = match.end;
    }
    if (cursor < text.length) {
      out.add(Segment(text.substring(cursor), isWord: false));
    }
    return out;
  }

  @override
  List<String> graphemes(String text, String? locale) {
    if (text.isEmpty) return const [];
    return [for (final match in _graphemeRe.allMatches(text)) match[0]!];
  }

  @override
  bool operator ==(Object other) => other is SpecSegmenter;

  @override
  int get hashCode => (SpecSegmenter).hashCode;
}
