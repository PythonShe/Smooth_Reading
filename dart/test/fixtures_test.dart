import 'package:test/test.dart';

import 'fixtures.dart';

/// Every case in `fixtures/common/*.json` must render identically in every
/// port (SPEC §6).
void main() {
  final cases = loadFixtures('common');

  test('every common fixture file is exercised', () {
    final files = cases.map((c) => c.file).toSet();
    expect(
        files,
        containsAll(<String>[
          'common/basic',
          'common/edge-cases',
          'common/markup',
          'common/options',
          'common/saccade',
          'common/scripts',
        ]));
  });

  group('common fixtures', () {
    for (final fixture in cases) {
      test(fixture.id, () => expect(fixture.render(), fixture.html));
    }
  });
}
