// Verifies that the published tarball contains only what `files` intends.
import { execFileSync } from 'node:child_process';

const allowed = /^(dist\/[^/]+|styles\.css|README\.md|LICENSE|package\.json)$/;
const out = execFileSync('pnpm', ['pack', '--dry-run', '--json'], { encoding: 'utf8' });
const json = JSON.parse(out.slice(out.indexOf('{')));
const files = (json.files ?? []).map((f) => f.path).sort();
const bad = files.filter((f) => !allowed.test(f));
const required = ['dist/index.js', 'dist/index.cjs', 'dist/index.d.ts', 'dist/index.d.cts', 'styles.css', 'README.md', 'LICENSE'];
const missing = required.filter((f) => !files.includes(f));
if (bad.length || missing.length) {
  console.error('pack-check failed.', { unexpected: bad, missing });
  process.exit(1);
}
console.log(`pack-check ok: ${files.length} files\n  ${files.join('\n  ')}`);
