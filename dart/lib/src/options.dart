import 'segment.dart';

/// Custom fixation-length algorithm (SPEC §2, "Custom override").
///
/// Receives the word exactly as tokenized, its grapheme-cluster count and the
/// options in force, and returns how many leading grapheme clusters to
/// emphasise. The result is clamped to `0..graphemes`.
typedef FixationLengthFn = int Function(
  String word,
  int graphemes,
  SmoothOptions options,
);

/// Algorithm options (`SmoothOptions` in SPEC §4) with the spec defaults.
///
/// Out-of-range values are clamped into range rather than rejected, exactly
/// as in every other port: [fixation] to `1..5`, [saccade] to `>= 1`,
/// [minWordLength] to `>= 0`. The constructor is `const`, so options can be
/// declared once and shared, including inside `const` Flutter widgets.
final class SmoothOptions {
  /// Creates options; every argument defaults to the spec default.
  const SmoothOptions({
    int fixation = 3,
    int saccade = 1,
    int minWordLength = 1,
    this.emphasizeNumbers = false,
    this.locale,
    this.fixationLength,
    this.segmenter = const SpecSegmenter(),
  })  : fixation = fixation < 1
            ? 1
            : fixation > 5
                ? 5
                : fixation,
        saccade = saccade < 1 ? 1 : saccade,
        minWordLength = minWordLength < 0 ? 0 : minWordLength;

  /// The spec defaults.
  static const SmoothOptions defaults = SmoothOptions();

  /// Fixation strength `1..5`: the proportion of each word that is emphasised
  /// (`0.20, 0.35, 0.50, 0.65, 0.80`). Default `3`.
  final int fixation;

  /// Saccade interval: emphasise every [saccade]-th word. Default `1`.
  final int saccade;

  /// Words with fewer grapheme clusters than this get no fixation. Default `1`.
  final int minWordLength;

  /// Whether words made only of decimal digits are emphasised. Default `false`.
  final bool emphasizeNumbers;

  /// BCP-47 language tag, passed to the [segmenter]. The built-in
  /// [SpecSegmenter] ignores it; a platform break iterator may use it.
  final String? locale;

  /// Replaces the built-in fixation algorithm when set.
  final FixationLengthFn? fixationLength;

  /// Supplies word boundaries and grapheme clusters. Defaults to the spec's
  /// regular-expression scanner; supply an ICU-backed [Segmenter] (for
  /// example over a Flutter platform channel) for dictionary-based Chinese,
  /// Japanese and Thai word breaks.
  final Segmenter segmenter;

  /// Fraction of each word that is emphasised at this [fixation] strength.
  double get ratio => fixationPercent[fixation]! / 100;

  /// A copy with the given fields replaced.
  SmoothOptions copyWith({
    int? fixation,
    int? saccade,
    int? minWordLength,
    bool? emphasizeNumbers,
    String? locale,
    FixationLengthFn? fixationLength,
    Segmenter? segmenter,
  }) {
    return SmoothOptions(
      fixation: fixation ?? this.fixation,
      saccade: saccade ?? this.saccade,
      minWordLength: minWordLength ?? this.minWordLength,
      emphasizeNumbers: emphasizeNumbers ?? this.emphasizeNumbers,
      locale: locale ?? this.locale,
      fixationLength: fixationLength ?? this.fixationLength,
      segmenter: segmenter ?? this.segmenter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SmoothOptions &&
      other.fixation == fixation &&
      other.saccade == saccade &&
      other.minWordLength == minWordLength &&
      other.emphasizeNumbers == emphasizeNumbers &&
      other.locale == locale &&
      other.fixationLength == fixationLength &&
      other.segmenter == segmenter;

  @override
  int get hashCode => Object.hash(
        fixation,
        saccade,
        minWordLength,
        emphasizeNumbers,
        locale,
        fixationLength,
        segmenter,
      );

  @override
  String toString() => 'SmoothOptions(fixation: $fixation, saccade: $saccade, '
      'minWordLength: $minWordLength, emphasizeNumbers: $emphasizeNumbers, '
      'locale: $locale)';
}

/// Fixation strength → percent of the word emphasised (SPEC §2), kept as
/// integers so `floor((n * percent + 50) / 100)` is exact in every port.
const Map<int, int> fixationPercent = {1: 20, 2: 35, 3: 50, 4: 65, 5: 80};
