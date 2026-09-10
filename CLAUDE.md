# Smooth Reading Monorepo Rules

Smooth Reading is an open-source library for *guided fixation reading*: the
leading letters of each word are emphasised so the eye has an artificial
fixation point. One documented algorithm, identical output in every port,
one first-party port per platform runtime. License: Apache-2.0.

| Directory | Package | Tech Stack | Description |
|------|------|--------|------|
| `packages/core/` | `@smooth-reading/core` | TypeScript, zero runtime deps | Tokenizer (`Intl.Segmenter` + regex fallback), `toHtml`, `applyToElement`, streaming transform, `styles.css` |
| `swift/` | `SmoothReading` (SPM) | Swift 6, iOS 17+/macOS 14+ | Same algorithm; `NSAttributedString` + `UILabel`/`NSTextField` helpers for UIKit/AppKit (primary), `AttributedString` for SwiftUI, `html()` |
| `android/` | `io.smoothreading:smooth-reading` | Kotlin, Gradle, minSdk 26 | Same algorithm; Compose `AnnotatedString`, `Spanned`, `toHtml()` |
| `python/` | `smooth-reading` (PyPI) | Python 3.10+, zero deps | Same algorithm, regex tokenizer, `smooth-reading` CLI |
| `fixtures/` | shared fixtures | JSON | `common/` must pass in every port; `segmenter/` only where an ICU word-breaker exists |
| `examples/` | demos | Vite | Playground apps, not published |
| `docs/` | docs | Markdown | `SPEC.md` is the contract; `docs/recipes/` holds framework snippets; `docs/internal/` is gitignored |

Support policy: first-party ports are exactly the four above, one per
platform runtime. Framework adapters (React, Vue, Svelte, Angular, …) are
never published as packages; they are copy-paste recipes in `docs/recipes/`.
Community forks are welcome to publish their own.

Algorithm boundary: `docs/SPEC.md` owns the rules (fixation ratio table,
round-half-up, saccade counting, tokenizer, HTML escaping). Code follows the
spec, never the other way round. If an implementation needs a rule the spec
lacks, add it to the spec in the same commit.

## Product Goals

- **CJK, other Asian scripts and RTL are the key selling point**, not an
  afterthought. Chinese, Japanese, Korean, Thai, Vietnamese, Hindi and other
  Indic scripts, Arabic, Hebrew, Persian and Urdu must work correctly in every
  ICU-backed port (core via `Intl.Segmenter`, Swift, Android) and degrade
  predictably in the regex-only Python port. `fixtures/segmenter/` and
  `fixtures/common/scripts.json` are the proof; a change that breaks one of
  those fixtures is a release blocker.
- Bidirectional text: emitted markup and attributed strings must never alter
  bidi ordering (no direction-changing wrappers, no `dir` attributes); the
  fixation is always the logical start of the word. Mixed LTR/RTL inputs are
  part of the fixture suite.
- Grapheme clusters, never code units: combining marks, Indic conjuncts,
  Thai vowel signs, Hangul jamo and emoji sequences are never split.

## Naming Policy

- The commercial product this technique is known by is a registered
  trademark. Never use that name in code, package names, keywords,
  identifiers, commit messages, docs, demo copy, or the website. The only
  permitted mention is one neutral README sentence: "similar to commercial
  fixation-reading products".
- Do not copy, subset or bundle any third-party fonts. Do not wrap or proxy
  any commercial API.
- Do not claim ADHD/dyslexia or speed-reading benefits. Cite the published
  studies neutrally (see root `README.md`, "What the evidence says").

## Stack Policy

- **Latest everything**: newest stable pnpm, TypeScript, Vite, Vitest, Swift,
  Kotlin, Gradle, Python and all dependencies. When bumping, query the registries
  (`npm view <pkg> version`, PyPI) for actual latest stable — never guess from
  training data. Record any forced downgrade (e.g. a tool that does not yet
  support the newest TypeScript) as a comment next to the pin.
- **pnpm, never npm/yarn**: `pnpm-lock.yaml` is the committed lockfile and the
  pnpm version is pinned by `packageManager` in the root `package.json`.
  `pnpm dlx` replaces `npx`.
- **Zero runtime dependencies in every port.** Platform APIs (ICU
  break iterators, `AttributedString`, Compose text) are fine; third-party
  libraries are not.
- **No `innerHTML` in recipes**: framework snippets render real elements from
  `tokenize()` output. `toHtml` output is for string contexts (SSR templates,
  static site generators, Markdown pipelines).
- **Apple platforms: UIKit/AppKit first, SwiftUI second.** The primary Swift
  API is `NSAttributedString` with real bold fonts derived from font
  descriptor traits, plus `UILabel`/`UITextView`/`NSTextField`/`NSTextView`
  helpers. `AttributedString` for SwiftUI is a convenience built on the same
  token walk. Never make a UIKit/AppKit feature depend on a SwiftUI type.
- **Android: one artifact serves both Views and Compose.**
  `smooth-reading-core` is pure JVM; `smooth-reading` adds `spanned()` for
  `TextView` and `annotatedString()` for Compose.
- **No `useEffect` in React code or recipes.** Render from `tokenize()` as a
  pure function of props (SSR/RSC safe, no re-run hazards). Fetched HTML is
  transformed in the data layer (`toHtml` inside a TanStack Query `select`,
  a route loader, or a server component), never in a post-mount effect. The
  only DOM integration (`applyToElement` on markup you do not own) uses a
  ref callback for the apply/restore lifecycle. The same spirit applies to
  other frameworks: derive, don't synchronise.
- **Presentation is CSS**: emit neutral markup (`<b>` or configurable
  tag/class); weight, colour and opacity live in `styles.css` custom
  properties.

## Scope Rules

- These root rules cover only monorepo-level constraints.
- For a task within one package, also follow that package's `README.md` API
  and keep its tests green: `pnpm --filter <name> build test typecheck`, or
  `cd python && pytest && mypy --strict smooth_reading`.
- Any change to the algorithm touches `docs/SPEC.md`, `fixtures/` and all
  four ports together; all fixture tests in all ports must pass in the same
  commit. Port test commands: `pnpm --filter @smooth-reading/core test`,
  `cd swift && swift test`, `cd android && ./gradlew test`,
  `cd python && pytest`.
- `AGENTS.md` is a verbatim copy of `CLAUDE.md` (for Codex and other agents).
  After editing `CLAUDE.md`, re-copy it over `AGENTS.md` in the same commit.

## Documentation Priority

- `docs/SPEC.md` — the algorithm and API contract. Read before touching
  tokenization, fixation length, HTML output or adapter APIs.
- Package `README.md` files — public API and usage; keep examples runnable.
- `docs/internal/` — research and planning notes; gitignored, never link to
  it from public docs.

## CI/CD (GitHub Actions)

- `ci.yml` — manual trigger only (`workflow_dispatch`; run via the Actions tab or `gh workflow run ci.yml`): JS on Node 24 (pnpm frozen install, build, typecheck, test),
  Swift (`swift test` on macOS), Android (`./gradlew test`), Python (pytest +
  mypy on 3.10 and latest).
- Publishing is manual for now (npm, SPM via git tag, Maven Central, PyPI).
  Versions are bumped together across all ports; keep every package at the
  same version and tag releases `vX.Y.Z`.
- No secrets enter git history.

## Git Conventions

- Commit and push in logical groups as work completes; the owner has granted
  this standing authorization.
- Never add "Generated with Claude Code" / `Co-Authored-By: Claude` footers.
- Commit message format: `<type>(<scope>): <description>` with type
  `feat/fix/refactor/docs/chore/test/perf/style` and scope:

| scope | Applicable scenario |
|-------|---------|
| `core` | Changes within `packages/core/` |
| `swift` | Changes within `swift/` |
| `android` | Changes within `android/` |
| `python` | Changes within `python/` |
| `recipes` | Changes within `docs/recipes/` |
| `fixtures` | Changes within `fixtures/` |
| `spec` | Changes to `docs/SPEC.md` |
| `examples` | Changes within `examples/` |
| `workspace` | Repo-root-level changes (`CLAUDE.md`, CI, root configs) |

Cross-package changes may combine scopes (`spec,core,python`).

## Directory Boundaries

- The repository root is not the root of any single package; do not place
  package-specific source or config at the root.
- Generated artifacts are never committed: `dist/`, `coverage/`,
  `node_modules/`, `python/.venv/`, `__pycache__/`, `*.egg-info/`,
  `swift/.build/`, `android/build/`, `android/.gradle/`.
- `docs/internal/` is gitignored on purpose; do not force-add it.
- No personal information (names, emails) in README or other public-facing
  docs. Copyright holder is "Smooth Reading contributors".

## Machine/Toolchain Gotchas (this dev machine)

- A shell hook rewrites common commands through `rtk` for token savings;
  long heredocs in a single Bash call can time out. Prefer writing files with
  the file tools or a short `python3 - <<'EOF'` script.
- Node 24 ships full ICU, so `Intl.Segmenter` fixtures run locally; CI uses
  the same Node major.
- Python 3.14 is the local default; the package must still support 3.10.
