import 'options.dart';

/// "Entirely digits" (SPEC §2 rule 1): decimal digits of any script, not ½
/// or Ⅻ.
final RegExp _allDigits = RegExp(r'^\p{Nd}+$', unicode: true);

/// The built-in fixation-length algorithm (SPEC §2): how many leading
/// grapheme clusters of [word] to emphasise, `0` meaning none.
///
/// Rules are applied in order: digit-only words are suppressed unless
/// `emphasizeNumbers` is set, words shorter than `minWordLength` are
/// suppressed, a single-character word is emphasised only at strength `>= 3`,
/// otherwise `clamp(round_half_up(n * ratio), 1, n)` computed with the integer
/// formula `floor((n * percent + 50) / 100)` so every port agrees exactly.
///
/// Exported so a custom [SmoothOptions.fixationLength] can delegate to it for
/// the cases it does not care about.
///
/// ```dart
/// fixationLength('reading', 7, SmoothOptions.defaults); // 4
/// ```
int fixationLength(String word, int graphemes, SmoothOptions options) {
  final n = graphemes;
  if (n <= 0) return 0;
  if (!options.emphasizeNumbers && _allDigits.hasMatch(word)) return 0;
  if (n < options.minWordLength) return 0;
  if (n == 1) return options.fixation >= 3 ? 1 : 0;
  final percent = fixationPercent[options.fixation]!;
  final raw = (n * percent + 50) ~/ 100;
  return raw < 1 ? 1 : (raw > n ? n : raw);
}
