import 'package:smooth_reading/smooth_reading.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Multilingual and bidi guarantees over every fixture input, including the
/// `segmenter` suite this regex port is not expected to *match*: tokens are
/// lossless, the markup adds nothing but emphasis tags, and no
/// direction-changing attribute or bidi control character is ever introduced.
void main() {
  final cases = [...loadFixtures('common'), ...loadFixtures('segmenter')];

  // LRM, RLM, ALM, the explicit embeddings/overrides and the isolates.
  final bidiControls =
      RegExp('[\\u200E\\u200F\\u061C\\u202A-\\u202E\\u2066-\\u2069]');

  String stripEmphasis(String markup, List<String> tags) {
    final names = tags.map(RegExp.escape).join('|');
    return markup.replaceAll(RegExp('</?(?:$names)(?:\\s[^>]*)?>'), '');
  }

  test('scripts and segmenter fixtures are present', () {
    expect(cases.any((c) => c.file == 'common/scripts'), isTrue);
    expect(cases.any((c) => c.file.startsWith('segmenter/')), isTrue);
  });

  for (final fixture in cases) {
    group(fixture.id, () {
      test('tokens are lossless', () {
        final tokens = tokenize(fixture.input, fixture.options);
        expect(tokens.map((t) => t.text).join(), fixture.input);
        for (final token in tokens.whereType<WordToken>()) {
          expect(token.fixationText + token.restText, token.text);
          expect(token.fixation, greaterThanOrEqualTo(0));
          expect(token.fixation == 0, token.fixationText.isEmpty);
        }
      });

      test('a word never starts with a combining mark', () {
        final mark = RegExp(r'^\p{M}', unicode: true);
        for (final token in tokenize(fixture.input, fixture.options)) {
          if (token is WordToken) expect(token.text, isNot(matches(mark)));
        }
      });

      test('markup adds only emphasis tags and never alters bidi', () {
        final rendered = fixture.render();
        final ignoreHtml =
            (fixture.rawOptions['ignoreHtmlTags'] as bool?) ?? true;
        if (!ignoreHtml || !fixture.input.contains(RegExp('[<&]'))) {
          expect(
            stripEmphasis(rendered, fixture.emphasisTags),
            escapeHtml(fixture.input),
          );
        }
        // No direction-changing markup is ever *added*.
        expect('dir='.allMatches(rendered).length,
            'dir='.allMatches(fixture.input).length);
        expect('<bdi'.allMatches(rendered).length,
            '<bdi'.allMatches(fixture.input).length);
        final inputControls = bidiControls.allMatches(fixture.input).length;
        final outputControls = bidiControls.allMatches(rendered).length;
        expect(outputControls, inputControls);
      });
    });
  }
}
