import 'options.dart';
import 'tokenize.dart';

/// Elements whose text content [toHtml] never touches (SPEC §4).
const List<String> defaultSkipTags = [
  'code',
  'pre',
  'script',
  'style',
  'kbd',
  'samp',
  'textarea',
];

// Markup passed through verbatim when `ignoreHtmlTags` is on, exactly as the
// TypeScript core lexes it (`packages/core/src/markup.ts`): a comment, a
// CDATA section, a tag or declaration (`<` only starts one when followed by a
// letter, `/`, `!` or `?`, and it ends at the next `>`; an unterminated
// comment or CDATA block degrades to that rule), or a character reference.
// Anything else, including an unterminated `<p`, is text and gets escaped.
final RegExp _markup = RegExp(
  r'<!--.*?-->'
  r'|<!\[CDATA\[.*?\]\]>'
  r'|<[A-Za-z/!?][^>]*>'
  r'|&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);',
  dotAll: true,
);
// A tag name runs until whitespace, `/` or `>` (`<code.x>` is named `code.x`);
// whitespace is allowed around the closing slash (`</ code>`).
final RegExp _tagName = RegExp(r'^<\s*(/?)\s*([A-Za-z][^\s/>]*)');
final RegExp _selfClosing = RegExp(r'/\s*>$');

/// Escapes exactly `& < > "` (SPEC §4); `'` stays so `don't` reads naturally.
String escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// A chunk of the input: raw markup to copy through, or prose to tokenize.
typedef _Chunk = ({bool raw, String text});

/// Splits [text] into raw chunks (markup, character references and the
/// content of [skipTags] elements, emitted verbatim) and prose chunks.
/// Character references therefore act as word boundaries.
Iterable<_Chunk> _splitMarkup(String text, Set<String> skipTags) sync* {
  String? skipName; // the skip element we are inside, if any
  var skipDepth = 0; // nesting of that same element: <pre><pre>..</pre></pre>
  var cursor = 0;
  for (final match in _markup.allMatches(text)) {
    if (match.start > cursor) {
      yield (raw: skipName != null, text: text.substring(cursor, match.start));
    }
    final raw = match[0]!;
    yield (raw: true, text: raw);
    cursor = match.end;

    final tag = _tagName.firstMatch(raw);
    if (tag == null) continue;
    final closing = tag[1] == '/';
    final name = tag[2]!.toLowerCase();
    if (_selfClosing.hasMatch(raw)) continue; // <br/>, <code / >
    if (skipName == null) {
      if (!closing && skipTags.contains(name)) {
        skipName = name;
        skipDepth = 1;
      }
    } else if (name == skipName) {
      skipDepth += closing ? -1 : 1;
      if (skipDepth <= 0) {
        skipName = null;
        skipDepth = 0;
      }
    }
  }
  if (cursor < text.length) {
    yield (raw: skipName != null, text: text.substring(cursor));
  }
}

String _wrap(String? tag, String? className, String body) {
  if (tag == null) return body;
  final attribute =
      className == null ? '' : ' class="${escapeHtml(className)}"';
  return '<$tag$attribute>$body</$tag>';
}

void _render(
  StringBuffer out,
  List<Token> tokens,
  String tag,
  String? className,
  String? restTag,
  String? restClassName,
) {
  for (final token in tokens) {
    if (token is! WordToken || token.fixation == 0) {
      out.write(escapeHtml(token.text));
      continue;
    }
    out.write(_wrap(tag, className, escapeHtml(token.fixationText)));
    // A fully emphasised word gets no (empty) rest element.
    if (token.restText.isNotEmpty) {
      out.write(_wrap(restTag, restClassName, escapeHtml(token.restText)));
    }
  }
}

/// Renders [text] as HTML with the leading part of each word emphasised
/// (SPEC §4).
///
/// Each fixation is wrapped in [tag] (with [className]); the rest of the word
/// is plain text unless [restTag] is given. Everything emitted as text has
/// `& < > "` escaped.
///
/// With [ignoreHtmlTags] (the default) existing tags, comments and character
/// references pass through verbatim, the content of [skipTags] elements, plus
/// [tag] and [restTag] themselves so already-emphasised markup is not wrapped
/// twice, is left untouched, and the saccade count continues across markup.
/// With `ignoreHtmlTags: false` the input is plain text and every `<`, `>`
/// and `&` is escaped.
///
/// ```dart
/// toHtml('Smooth reading works.');
/// // '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'
/// ```
String toHtml(
  String text, {
  SmoothOptions options = SmoothOptions.defaults,
  String tag = 'b',
  String? className,
  String? restTag,
  String? restClassName,
  bool ignoreHtmlTags = true,
  Iterable<String> skipTags = defaultSkipTags,
}) {
  final out = StringBuffer();
  if (!ignoreHtmlTags) {
    _render(
        out, tokenize(text, options), tag, className, restTag, restClassName);
    return out.toString();
  }
  final skipped = {
    for (final name in skipTags) name.toLowerCase(),
    tag.toLowerCase(),
    if (restTag != null) restTag.toLowerCase(),
  };
  final state = TokenizeState();
  for (final chunk in _splitMarkup(text, skipped)) {
    if (chunk.raw) {
      out.write(chunk.text);
    } else {
      final tokens = tokenizeWithState(chunk.text, options, state);
      _render(out, tokens, tag, className, restTag, restClassName);
    }
  }
  return out.toString();
}

/// Renders [text] as Markdown, wrapping each fixation in [marker].
///
/// Nothing is escaped; the input is assumed to be Markdown already.
///
/// ```dart
/// toMarkdown('Smooth reading works.');
/// // '**Smo**oth **read**ing **wor**ks.'
/// ```
String toMarkdown(
  String text, {
  SmoothOptions options = SmoothOptions.defaults,
  String marker = '**',
}) {
  final out = StringBuffer();
  for (final token in tokenize(text, options)) {
    if (token is WordToken && token.fixation > 0) {
      out
        ..write(marker)
        ..write(token.fixationText)
        ..write(marker)
        ..write(token.restText);
    } else {
      out.write(token.text);
    }
  }
  return out.toString();
}
