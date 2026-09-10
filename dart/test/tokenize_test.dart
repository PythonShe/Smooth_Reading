import 'package:smooth_reading/smooth_reading.dart';
import 'package:test/test.dart';

List<WordToken> words(String text, [SmoothOptions? options]) =>
    tokenize(text, options ?? SmoothOptions.defaults)
        .whereType<WordToken>()
        .toList();

void main() {
  group('tokenize', () {
    test('returns nothing for an empty string', () {
      expect(tokenize(''), isEmpty);
    });

    test('splits words and separators and round-trips the input', () {
      final tokens = tokenize('Smooth reading works.');
      expect(tokens.map((t) => t.runtimeType), [
        WordToken,
        SeparatorToken,
        WordToken,
        SeparatorToken,
        WordToken,
        SeparatorToken,
      ]);
      expect(tokens.map((t) => t.text).join(), 'Smooth reading works.');
    });

    test('computes the fixation prefix in graphemes', () {
      expect(
        words('reading').single,
        const WordToken(
          'reading',
          fixation: 4,
          fixationText: 'read',
          restText: 'ing',
        ),
      );
    });

    test('merges consecutive separators into one token', () {
      final separators =
          tokenize('hi ... there').whereType<SeparatorToken>().toList();
      expect(separators.map((t) => t.text), [' ... ']);
    });

    test('treats a combining mark as part of its base grapheme', () {
      final word = words('naïve').single; // decomposed ï
      expect(word.fixation, 3);
      expect(word.fixationText, 'naï');
      expect(word.restText, 've');
    });

    test('keeps apostrophe contractions together and splits hyphens', () {
      expect(words("don't it’s well-known").map((w) => w.text),
          ["don't", 'it’s', 'well', 'known']);
    });

    test('does not emphasise pure numbers by default', () {
      expect(words('2024').single.fixation, 0);
      expect(
        words('2024', const SmoothOptions(emphasizeNumbers: true))
            .single
            .fixation,
        2,
      );
      // Arabic-Indic digits are decimal digits too.
      expect(words('٢٠٢٤').single.fixation, 0);
    });

    test('single-character words need strength 3 or more', () {
      expect(words('a').single.fixation, 1);
      expect(words('a', const SmoothOptions(fixation: 2)).single.fixation, 0);
      expect(words('我', const SmoothOptions(fixation: 1)).single.fixation, 0);
    });

    test('numbers and short words still consume a saccade index', () {
      final tokens = words('one 2 three four', const SmoothOptions(saccade: 2));
      expect(tokens.map((w) => w.fixation), [2, 0, 3, 0]);
    });

    test('a combining mark after a separator stays with the separator', () {
      final tokens = tokenize('I ❤️ Dart');
      expect(tokens.whereType<SeparatorToken>().map((t) => t.text), [' ❤️ ']);
    });

    test('astral code points are one grapheme', () {
      final word = words('𝔘𝔫𝔦𝔠𝔬𝔡𝔢').single; // 7 mathematical letters
      expect(word.fixation, 4);
      expect(word.fixationText, '𝔘𝔫𝔦𝔠');
    });

    test('decomposed Hangul jamo compose into syllables', () {
      const precomposed = '한국어';
      const decomposed = '한국어';
      expect(words(decomposed).single.fixation,
          words(precomposed).single.fixation);
      expect(words(decomposed).single.fixationText, '한국');
    });

    test('Indic conjuncts are never split (GB9c)', () {
      // क्षत्रिय = क्ष | त्रि | य : three clusters, prefix two.
      final word = words('क्षत्रिय').single;
      expect(word.fixation, 2);
      expect(word.fixationText, 'क्षत्रि');
      expect(word.restText, 'य');
    });

    test('a no-space-script run is one word in the regex segmenter', () {
      expect(words('我喜欢阅读').single.fixationText, '我喜欢');
      expect(words('ภาษาไทย').single.text, 'ภาษาไทย');
    });

    test('a run is split from adjacent text of other scripts', () {
      expect(words('iPhone手机很好用').map((w) => w.text), ['iPhone', '手机很好用']);
      expect(words('abcก').map((w) => w.text), ['abc', 'ก']);
      expect(words('日本語OKです').map((w) => w.text), ['日本語', 'OK', 'です']);
      // A combining mark after a run character stays in the run.
      expect(words('我\u0301x').map((w) => w.text), ['我\u0301', 'x']);
    });
  });

  group('fixationLength', () {
    test('follows the spec reference table', () {
      const cases = {
        'a': 1,
        'to': 1,
        'the': 2,
        'read': 2,
        'smooth': 3,
        'reading': 4,
      };
      cases.forEach((word, expected) {
        expect(
            fixationLength(word, word.length, SmoothOptions.defaults), expected,
            reason: word);
      });
      expect(fixationLength('2024', 4, SmoothOptions.defaults), 0);
    });

    test('uses integer round-half-up for every strength', () {
      // n = 10: 20% -> 2, 35% -> 4 (3.5 rounds up), 50% -> 5, 65% -> 7
      // (6.5 rounds up), 80% -> 8.
      final results = [
        for (var s = 1; s <= 5; s++)
          fixationLength('abcdefghij', 10, SmoothOptions(fixation: s)),
      ];
      expect(results, [2, 4, 5, 7, 8]);
    });

    test('a custom override is clamped to 0..n', () {
      int always99(String word, int graphemes, SmoothOptions options) => 99;
      int negative(String word, int graphemes, SmoothOptions options) => -1;
      expect(
        words('word', SmoothOptions(fixationLength: always99)).single.fixation,
        4,
      );
      expect(
        words('word', SmoothOptions(fixationLength: negative)).single.fixation,
        0,
      );
    });
  });

  group('SmoothOptions', () {
    test('clamps out-of-range values instead of throwing', () {
      expect(const SmoothOptions(fixation: 0).fixation, 1);
      expect(const SmoothOptions(fixation: 9).fixation, 5);
      expect(const SmoothOptions(saccade: 0).saccade, 1);
      expect(const SmoothOptions(saccade: -3).saccade, 1);
      expect(const SmoothOptions(minWordLength: -1).minWordLength, 0);
    });

    test('exposes the ratio table', () {
      expect(const SmoothOptions(fixation: 1).ratio, 0.2);
      expect(const SmoothOptions(fixation: 5).ratio, 0.8);
    });

    test('copyWith and equality', () {
      const base = SmoothOptions();
      expect(base.copyWith(fixation: 4), const SmoothOptions(fixation: 4));
      expect(base.copyWith(), base);
    });
  });

  group('custom Segmenter', () {
    test('supplies word boundaries and graphemes', () {
      final tokens = tokenize(
          '我喜欢阅读', const SmoothOptions(segmenter: _DictionarySegmenter()));
      expect(tokens.map((t) => t.text), ['我', '喜欢', '阅读']);
      expect(tokens.whereType<WordToken>().map((w) => w.fixationText),
          ['我', '喜', '阅']);
    });

    test('separators from a segmenter are merged', () {
      final tokens = tokenize(
          'a, b', const SmoothOptions(segmenter: _CharacterSegmenter()));
      expect(tokens.map((t) => t.text), ['a', ', ', 'b']);
    });
  });
}

/// A stand-in for an ICU dictionary: knows three Chinese words.
final class _DictionarySegmenter extends Segmenter {
  const _DictionarySegmenter();

  @override
  List<Segment> segmentWords(String text, String? locale) {
    const dictionary = ['我', '喜欢', '阅读'];
    final out = <Segment>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final word = dictionary.firstWhere(rest.startsWith,
          orElse: () => rest.substring(0, 1));
      out.add(Segment(word, isWord: dictionary.contains(word)));
      rest = rest.substring(word.length);
    }
    return out;
  }

  @override
  List<String> graphemes(String text, String? locale) =>
      const SpecSegmenter().graphemes(text, locale);
}

/// Emits every code unit as its own segment, punctuation one at a time.
final class _CharacterSegmenter extends Segmenter {
  const _CharacterSegmenter();

  @override
  List<Segment> segmentWords(String text, String? locale) => [
        for (final char in text.split(''))
          Segment(char, isWord: RegExp(r'\p{L}', unicode: true).hasMatch(char)),
      ];

  @override
  List<String> graphemes(String text, String? locale) => text.split('');
}
