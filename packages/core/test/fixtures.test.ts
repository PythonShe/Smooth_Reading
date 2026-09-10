import { describe, expect, it } from 'vitest';
import { toHtml, tokenize, usesIntlSegmenter } from '../src/index.js';
import { loadFixtures } from './fixtures.js';
import type { Fixture } from './fixtures.js';

/**
 * Escape exactly as `toHtml` does for emitted text (SPEC §4), so a fixture
 * with no markup of its own must come back as `escape(input)` once the
 * emphasis tags are removed.
 */
const escapeHtml = (text: string): string =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const escapeRegExp = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Remove every emphasis wrapper `toHtml` could have emitted for these options. */
function stripEmphasisTags(html: string, options: Fixture['options']): string {
  const tags = [options?.tag ?? 'b', options?.restTag].filter((t): t is string => t !== undefined);
  return tags.reduce(
    (out, tag) => out.replace(new RegExp(`</?${escapeRegExp(tag)}(?: class="[^"]*")?>`, 'g'), ''),
    html,
  );
}

/** Inputs whose only `<`/`&` are ones `toHtml` would escape: no tags, no character references. */
const hasMarkup = (input: string): boolean => /<[a-zA-Z/!?]|&(?:#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/.test(input);

function losslessSuite(files: ReturnType<typeof loadFixtures>): void {
  describe('token texts concatenate back to the input (lossless)', () => {
    for (const { file, cases } of files) {
      it(file, () => {
        for (const fixture of cases) {
          const joined = tokenize(fixture.input, fixture.options).map((t) => t.text).join('');
          expect(joined, fixture.name).toBe(fixture.input);
        }
      });
    }
  });

  describe('output stripped of emphasis tags is the escaped input', () => {
    for (const { file, cases } of files) {
      it(file, () => {
        let checked = 0;
        for (const fixture of cases) {
          if (hasMarkup(fixture.input)) continue;
          const stripped = stripEmphasisTags(toHtml(fixture.input, fixture.options), fixture.options);
          expect(stripped, fixture.name).toBe(escapeHtml(fixture.input));
          checked += 1;
        }
        expect(checked, `${file} has no markup-free inputs`).toBeGreaterThan(0);
      });
    }
  });
}

describe('shared fixtures: common', () => {
  const files = loadFixtures('common');

  it('finds every common fixture file', () => {
    expect(files.map((f) => f.file)).toEqual(expect.arrayContaining([
      'common/basic.json',
      'common/edge-cases.json',
      'common/markup.json',
      'common/options.json',
      'common/saccade.json',
      'common/scripts.json',
    ]));
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

  losslessSuite(files);
});

describe.skipIf(!usesIntlSegmenter())('shared fixtures: segmenter', () => {
  const files = loadFixtures('segmenter');

  for (const { file, cases } of files) {
    describe(file, () => {
      for (const fixture of cases) {
        it(fixture.name, () => {
          expect(toHtml(fixture.input, fixture.options)).toBe(fixture.html);
        });
      }
    });
  }

  losslessSuite(files);
});
