/// Guided fixation reading for Dart and Flutter.
///
/// Emphasises the leading grapheme clusters of every word so the eye gets an
/// artificial fixation point. Deterministic, language-agnostic and
/// dependency-free; the algorithm is defined by `docs/SPEC.md` in the project
/// repository and produces the same output as the TypeScript, Swift, Kotlin
/// and Python ports.
///
/// ```dart
/// import 'package:smooth_reading/smooth_reading.dart';
///
/// toHtml('Smooth reading works.');
/// // '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
///
/// for (final token in tokenize('Smooth reading')) {
///   switch (token) {
///     case WordToken(:final fixationText, :final restText):
///       // build a bold TextSpan for fixationText and a plain one for restText
///     case SeparatorToken(:final text):
///       // plain TextSpan
///   }
/// }
/// ```
library;

export 'src/fixation.dart' show fixationLength;
export 'src/html.dart' show defaultSkipTags, escapeHtml, toHtml, toMarkdown;
export 'src/options.dart' show FixationLengthFn, SmoothOptions;
export 'src/segment.dart' show Segment, Segmenter, SpecSegmenter;
export 'src/tokenize.dart'
    show
        SeparatorToken,
        Token,
        TokenizeState,
        WordToken,
        tokenize,
        tokenizeWithState;
export 'src/version.dart' show packageVersion;
