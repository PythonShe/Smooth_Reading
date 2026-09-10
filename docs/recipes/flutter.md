# Flutter

Built on the [`smooth_reading`](../../dart) Dart package (`dart pub add smooth_reading`). Flutter is a framework, so, as with React or Vue, there is no separate widget package: copy the widget below into your app. `tokenize()` is a pure, synchronous function, so the widget is a plain `StatelessWidget` that derives its spans from its inputs. No `initState`, no `setState`, no HTML.

## `SmoothText` widget

```dart
import 'package:flutter/material.dart';
import 'package:smooth_reading/smooth_reading.dart';

/// Renders [text] with the leading part of each word emphasised.
class SmoothText extends StatelessWidget {
  const SmoothText(
    this.text, {
    super.key,
    this.options = SmoothOptions.defaults,
    this.style,
    this.fixationStyle,
    this.restStyle,
    this.textAlign,
    this.selectable = false,
  });

  final String text;
  final SmoothOptions options;

  /// Base style; defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Style merged onto the fixation; defaults to `fontWeight: w700`.
  final TextStyle? fixationStyle;

  /// Style merged onto the rest of each word (for example a lower opacity).
  final TextStyle? restStyle;

  final TextAlign? textAlign;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final fixation =
        base.merge(fixationStyle ?? const TextStyle(fontWeight: FontWeight.w700));
    final rest = base.merge(restStyle);
    final span = TextSpan(
      style: base,
      children: [
        for (final token in tokenize(text, options))
          switch (token) {
            WordToken(fixation: > 0, :final fixationText, :final restText) =>
              TextSpan(children: [
                TextSpan(text: fixationText, style: fixation),
                if (restText.isNotEmpty) TextSpan(text: restText, style: rest),
              ]),
            WordToken(:final text) || SeparatorToken(:final text) =>
              TextSpan(text: text),
          },
      ],
    );
    return selectable
        ? SelectableText.rich(span, textAlign: textAlign)
        : Text.rich(span, textAlign: textAlign);
  }
}
```

Usage:

```dart
const SmoothText('Smooth reading works.')

SmoothText(
  article.body,
  options: const SmoothOptions(fixation: 4, saccade: 2),
  restStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  selectable: true,
)
```

Notes:

- **Bidi is preserved.** Arabic, Hebrew, Persian and Urdu render right-to-left because Flutter lays out the logical string; the fixation is always the logical start of the word, and no direction override is inserted. Wrap in `Directionality` as you would any text.
- **Real bold, not faux bold.** `FontWeight.w700` selects the bold face of the font family (or the matching instance of a variable font). If your family has no bold face, pick a weight it has, or use colour or opacity for the fixation instead of weight.
- **Long text.** `tokenize` is linear and cheap; for very long articles split by paragraph so each `SmoothText` is a separate render object.
- **`const` all the way.** `SmoothOptions` has a `const` constructor, so `const SmoothText('…', options: SmoothOptions(fixation: 4))` is valid and never rebuilds.

## Rendering HTML you do not own

If your content arrives as HTML (a CMS, Markdown rendered on the server), transform it in the data layer with `toHtml()` and render the result with your HTML widget of choice. Do not transform in `build()` on every frame; do it once where the data is loaded.

```dart
Future<String> loadArticle(Uri uri) async {
  final html = await fetch(uri);
  return toHtml(html, tag: 'span', className: 'sr-fixation');
}
```

## Dictionary word breaks for Chinese, Japanese and Thai

The default `SpecSegmenter` treats each unbroken run of Han, Kana or Hangul as one word, the same predictable rule the Python port uses. Flutter apps can get ICU dictionary breaks from the host platform with a small platform channel and plug them in through the `Segmenter` interface. The fixation algorithm, saccade counting and rendering stay in Dart.

Dart side:

```dart
import 'package:flutter/services.dart';
import 'package:smooth_reading/smooth_reading.dart';

final class PlatformSegmenter extends Segmenter {
  const PlatformSegmenter();

  static const _channel = MethodChannel('smooth_reading/segmenter');

  /// Word breaks are fetched once per text; keep results in your data layer
  /// (a cached provider) rather than calling this from build().
  static Future<List<Segment>> breakWords(String text, String? locale) async {
    final raw = await _channel.invokeListMethod<Object?>(
        'words', {'text': text, 'locale': locale});
    // Each entry is [text, isWord].
    return [
      for (final entry in raw!.cast<List<Object?>>())
        Segment(entry[0]! as String, isWord: entry[1]! as bool),
    ];
  }

  @override
  List<Segment> segmentWords(String text, String? locale) =>
      throw UnsupportedError('use breakWords() and cache the result');

  @override
  List<String> graphemes(String text, String? locale) =>
      const SpecSegmenter().graphemes(text, locale);
}

/// A segmenter that replays segments already fetched from the platform.
final class PrecomputedSegmenter extends Segmenter {
  const PrecomputedSegmenter(this.segments);
  final List<Segment> segments;

  @override
  List<Segment> segmentWords(String text, String? locale) => segments;

  @override
  List<String> graphemes(String text, String? locale) =>
      const SpecSegmenter().graphemes(text, locale);
}
```

Then, in your data layer: `final segments = await PlatformSegmenter.breakWords(text, 'zh');` and in the widget: `SmoothText(text, options: SmoothOptions(segmenter: PrecomputedSegmenter(segments)))`.

Android handler (Kotlin), using the same ICU class the Android port uses:

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smooth_reading/segmenter")
    .setMethodCallHandler { call, result ->
        val text = call.argument<String>("text")!!
        val locale = call.argument<String?>("locale")?.let(Locale::forLanguageTag) ?: Locale.getDefault()
        val it = android.icu.text.BreakIterator.getWordInstance(locale).apply { setText(text) }
        val out = ArrayList<List<Any>>()
        var start = it.first()
        var end = it.next()
        while (end != android.icu.text.BreakIterator.DONE) {
            val isWord = it.ruleStatus != android.icu.text.BreakIterator.WORD_NONE
            out.add(listOf(text.substring(start, end), isWord))
            start = end; end = it.next()
        }
        result.success(out)
    }
```

iOS handler (Swift), using the same tokenizer the Swift port uses:

```swift
let channel = FlutterMethodChannel(name: "smooth_reading/segmenter", binaryMessenger: controller.binaryMessenger)
channel.setMethodCallHandler { call, result in
    let args = call.arguments as! [String: Any?]
    let text = args["text"] as! String
    let locale = (args["locale"] as? String).map(Locale.init(identifier:))
    var out: [[Any]] = []
    var cursor = text.startIndex
    text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, range, _, _ in
        if cursor < range.lowerBound { out.append([String(text[cursor..<range.lowerBound]), false]) }
        out.append([String(text[range]), true])
        cursor = range.upperBound
    }
    if cursor < text.endIndex { out.append([String(text[cursor...]), false]) }
    _ = locale // pass to CFStringTokenizer if you need locale-specific breaks
    result(out)
}
```

On Flutter web, `Intl.Segmenter` is available through `package:web` / JS interop and can back the same `Segmenter` interface synchronously.
