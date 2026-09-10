import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { HtmlOptions } from '../src/index.js';

export interface Fixture {
  name: string;
  input: string;
  options: HtmlOptions;
  html: string;
}

export interface FixtureFile {
  file: string;
  cases: Fixture[];
}

const fixturesRoot = fileURLToPath(new URL('../../../fixtures/', import.meta.url));

/** Load every `*.json` fixture file from `fixtures/<group>`. */
export function loadFixtures(group: 'common' | 'segmenter'): FixtureFile[] {
  const dir = join(fixturesRoot, group);
  return readdirSync(dir)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => ({
      file: `${group}/${name}`,
      cases: JSON.parse(readFileSync(join(dir, name), 'utf8')) as Fixture[],
    }));
}
