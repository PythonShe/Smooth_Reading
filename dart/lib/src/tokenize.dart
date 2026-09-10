import 'fixation.dart';
import 'options.dart';

/// A piece of the input: a [WordToken] or a [SeparatorToken].
///
/// Concatenating `token.text` over the list returned by [tokenize] gives the
/// input back unchanged. The class is sealed, so a `switch` over tokens is
/// exhaustive, which is what a Flutter `TextSpan` builder wants.
sealed class Token {
  const Token._(this.text);

  /// The exact slice of the input this token covers.
  final String text;
}

/// A word, with its fixation split.
final class WordToken extends Token {
  /// Creates a word token. `fixationText + restText` must equal `text`.
  const WordToken(
    super.text, {
    required this.fixation,
    required this.fixationText,
    required this.restText,
  }) : super._();

  /// A word that receives no emphasis: [fixation] `0`, all text in [restText].
  const WordToken.plain(String text)
      : this(text, fixation: 0, fixationText: '', restText: text);

  /// Number of emphasised leading grapheme clusters; `0` when the word gets
  /// no fixation (suppressed by a rule, or off the saccade beat).
  final int fixation;

  /// The emphasised prefix (empty when [fixation] is `0`).
  final String fixationText;

  /// The rest of the word (the whole word when [fixation] is `0`).
  final String restText;

  @override
  bool operator ==(Object other) =>
      other is WordToken &&
      other.text == text &&
      other.fixation == fixation &&
      other.fixationText == fixationText &&
      other.restText == restText;

  @override
  int get hashCode => Object.hash(text, fixation, fixationText, restText);

  @override
  String toString() =>
      'WordToken($text, fixation: $fixation, "$fixationText" + "$restText")';
}

/// Whitespace, punctuation, emoji or other non-word text between words.
final class SeparatorToken extends Token {
  /// Creates a separator token.
  const SeparatorToken(super.text) : super._();

  @override
  bool operator ==(Object other) =>
      other is SeparatorToken && other.text == text;

  @override
  int get hashCode => Object.hash(SeparatorToken, text);

  @override
  String toString() => 'SeparatorToken($text)';
}

/// Saccade bookkeeping shared across several [tokenizeWithState] calls, so
/// [toHtml] keeps counting words across markup (SPEC §4).
final class TokenizeState {
  /// Creates a counter starting at [wordIndex].
  TokenizeState([this.wordIndex = 0]);

  /// Index of the next word token; the first word of the input is `0`.
  int wordIndex;
}

/// Splits [text] into words and separators and computes each word's fixation
/// prefix (SPEC §3, §4).
///
/// ```dart
/// tokenize('Smooth reading');
/// // [WordToken(Smooth, fixation: 3, "Smo" + "oth"),
/// //  SeparatorToken( ),
/// //  WordToken(reading, fixation: 4, "read" + "ing")]
/// ```
List<Token> tokenize(
  String text, [
  SmoothOptions options = SmoothOptions.defaults,
]) =>
    tokenizeWithState(text, options, TokenizeState());

/// [tokenize] with an externally owned saccade counter.
List<Token> tokenizeWithState(
  String text,
  SmoothOptions options,
  TokenizeState state,
) {
  final tokens = <Token>[];
  for (final segment in options.segmenter.segmentWords(text, options.locale)) {
    if (segment.text.isEmpty) continue;
    if (segment.isWord) {
      tokens.add(_wordToken(segment.text, options, state));
    } else if (tokens.isNotEmpty && tokens.last is SeparatorToken) {
      // Consecutive separators merge into one token so every segmenter
      // produces the same token stream.
      tokens.last = SeparatorToken(tokens.last.text + segment.text);
    } else {
      tokens.add(SeparatorToken(segment.text));
    }
  }
  return tokens;
}

WordToken _wordToken(String word, SmoothOptions options, TokenizeState state) {
  // Every word token consumes a saccade index, including numbers and words
  // too short to be emphasised (SPEC §4).
  final onSaccade = state.wordIndex % options.saccade == 0;
  state.wordIndex += 1;
  if (!onSaccade) return WordToken.plain(word);

  final graphemes = options.segmenter.graphemes(word, options.locale);
  final n = graphemes.length;
  final requested = options.fixationLength == null
      ? fixationLength(word, n, options)
      : options.fixationLength!(word, n, options);
  final fixation = requested < 0 ? 0 : (requested > n ? n : requested);
  if (fixation == 0) return WordToken.plain(word);
  return WordToken(
    word,
    fixation: fixation,
    fixationText: graphemes.take(fixation).join(),
    restText: graphemes.skip(fixation).join(),
  );
}
