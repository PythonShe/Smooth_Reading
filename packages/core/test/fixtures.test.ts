import { describe, expect, it } from 'vitest';
import { toHtml, usesIntlSegmenter } from '../src/index.js';
import { loadFixtures } from './fixtures.js';

describe('shared fixtures: common', () => {
  const files = loadFixtures('common');

  it('finds every common fixture file', () => {
    expect(files.map((f) => f.file)).toEqual([
      'common/basic.json',
      'common/edge-cases.json',
      'common/options.json',
      'common/saccade.json',
    ]);
  });

  for (const { file, cases } of files) {
    describe(file, () => {
      it('is not empty', () => {
        expect(cases.length).toBeGreaterThan(0);
      });

      for (const fixture of cases) {
        it(fixture.name, () => {
          expect(toHtml(fixture.input, fixture.options)).toBe(fixture.html);
        });
      }
    });
  }
});

describe.skipIf(!usesIntlSegmenter())('shared fixtures: segmenter', () => {
  for (const { file, cases } of loadFixtures('segmenter')) {
    describe(file, () => {
      for (const fixture of cases) {
        it(fixture.name, () => {
          expect(toHtml(fixture.input, fixture.options)).toBe(fixture.html);
        });
      }
    });
  }
});
