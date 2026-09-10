// ignore_for_file: avoid_print

import 'package:smooth_reading/smooth_reading.dart';

void main() {
  // HTML for string contexts (server templates, static sites, Markdown
  // pipelines).
  print(toHtml('Smooth reading works.'));
  // <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.

  // Strength and saccade interval.
  print(toHtml('Smooth reading works.',
      options: const SmoothOptions(fixation: 5, saccade: 2)));
  // <b>Smoot</b>h reading <b>work</b>s.

  // Tokens for rendering with your own primitives (Flutter TextSpan, a
  // terminal UI, a PDF generator).
  for (final token in tokenize('Smooth reading')) {
    switch (token) {
      case WordToken(:final fixationText, :final restText):
        print('[$fixationText]$restText');
      case SeparatorToken(:final text):
        print('separator "$text"');
    }
  }
  // [Smo]oth
  // separator " "
  // [read]ing

  // Markdown.
  print(toMarkdown('Smooth reading works.'));
  // **Smo**oth **read**ing **wor**ks.
}
