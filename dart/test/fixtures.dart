import 'dart:convert';
import 'dart:io';

import 'package:smooth_reading/smooth_reading.dart';

/// One case from `fixtures/<group>/<file>.json`.
final class Fixture {
  Fixture(this.file, Map<String, Object?> json)
      : name = json['name']! as String,
        input = json['input']! as String,
        html = json['html']! as String,
        rawOptions = (json['options'] as Map<String, Object?>?) ?? const {};

  final String file;
  final String name;
  final String input;
  final String html;
  final Map<String, Object?> rawOptions;

  String get id => '$file: $name';

  static const _algorithmKeys = {
    'fixation',
    'saccade',
    'minWordLength',
    'emphasizeNumbers',
    'locale',
  };
  static const _htmlKeys = {
    'tag',
    'className',
    'restTag',
    'restClassName',
    'ignoreHtmlTags',
    'skipTags',
  };

  /// Algorithm options, using the spec's camelCase names.
  SmoothOptions get options {
    for (final key in rawOptions.keys) {
      if (!_algorithmKeys.contains(key) && !_htmlKeys.contains(key)) {
        throw StateError('$id: unknown fixture option $key');
      }
    }
    return SmoothOptions(
      fixation: (rawOptions['fixation'] as int?) ?? 3,
      saccade: (rawOptions['saccade'] as int?) ?? 1,
      minWordLength: (rawOptions['minWordLength'] as int?) ?? 1,
      emphasizeNumbers: (rawOptions['emphasizeNumbers'] as bool?) ?? false,
      locale: rawOptions['locale'] as String?,
    );
  }

  /// The fixture's HTML options fed to [toHtml].
  String render() => toHtml(
        input,
        options: options,
        tag: (rawOptions['tag'] as String?) ?? 'b',
        className: rawOptions['className'] as String?,
        restTag: rawOptions['restTag'] as String?,
        restClassName: rawOptions['restClassName'] as String?,
        ignoreHtmlTags: (rawOptions['ignoreHtmlTags'] as bool?) ?? true,
        skipTags: (rawOptions['skipTags'] as List<Object?>?)?.cast<String>() ??
            defaultSkipTags,
      );

  /// The emphasis tags the rendered markup may contain.
  List<String> get emphasisTags => [
        (rawOptions['tag'] as String?) ?? 'b',
        if (rawOptions['restTag'] != null) rawOptions['restTag']! as String,
      ];
}

/// The repository's `fixtures/` directory, resolved from the package root.
final Directory fixturesRoot = () {
  // `dart test` runs with the package directory as the working directory.
  final dir = Directory('../fixtures');
  if (!dir.existsSync()) {
    throw StateError('fixtures directory not found at ${dir.absolute.path}');
  }
  return dir;
}();

/// Every case in `fixtures/<group>/*.json`, in file order.
List<Fixture> loadFixtures(String group) {
  final files = Directory('${fixturesRoot.path}/$group')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      for (final json in jsonDecode(file.readAsStringSync()) as List<Object?>)
        Fixture(
          '$group/${file.uri.pathSegments.last.replaceAll('.json', '')}',
          json! as Map<String, Object?>,
        ),
  ];
}
