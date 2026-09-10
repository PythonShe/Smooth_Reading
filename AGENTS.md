# Smooth Reading Monorepo Rules

Smooth Reading is an open-source library for *guided fixation reading*: the
leading letters of each word are emphasised so the eye has an artificial
fixation point. One documented algorithm, identical output in every port,
first-class adapters for mainstream frameworks. License: Apache-2.0.

| Directory | Package | Tech Stack | Description |
|------|------|--------|------|
| `packages/core/` | `@smooth-reading/core` | TypeScript, zero runtime deps | Tokenizer (`Intl.Segmenter` + regex fallback), `toHtml`, `applyToElement`, streaming transform, `styles.css` |
| `packages/react/` | `@smooth-reading/react` | React 19 | `<SmoothText>`, `useSmoothTokens`, `SmoothProvider`; SSR/RSC safe |
| `packages/vue/` | `@smooth-reading/vue` | Vue 3.5 | `<SmoothText>`, `vSmooth` directive, `useSmoothTokens` |
| `packages/svelte/` | `@smooth-reading/svelte` | Svelte 5 runes | `<SmoothText>`, `smooth` action |
| `packages/dom/` | `@smooth-reading/dom` | Web Components | `<smooth-reading>` custom element, `applyToElement` re-export |
| `python/` | `smooth-reading` (PyPI) | Python 3.10+, zero deps | Same algorithm, regex tokenizer, `smooth-reading` CLI |
| `fixtures/` | shared fixtures | JSON | `common/` must pass in every port; `segmenter/` only where `Intl.Segmenter` exists |
| `examples/` | demos | Vite | Playground apps, not published |
| `docs/` | docs | Markdown | `SPEC.md` is the contract; `docs/internal/` is gitignored |

Algorithm boundary: `docs/SPEC.md` owns the rules (fixation ratio table,
round-half-up, saccade counting, tokenizer, HTML escaping). Code follows the
spec, never the other way round. If an implementation needs a rule the spec
lacks, add it to the spec in the same commit.

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

- **Latest everything**: newest stable pnpm, TypeScript, Vite, Vitest, React,
  Vue, Svelte, Python and all dependencies. When bumping, query the registries
  (`npm view <pkg> version`, PyPI) for actual latest stable — never guess from
  training data. Record any forced downgrade (e.g. a tool that does not yet
  support the newest TypeScript) as a comment next to the pin.
- **pnpm, never npm/yarn**: `pnpm-lock.yaml` is the committed lockfile and the
  pnpm version is pinned by `packageManager` in the root `package.json`.
  `pnpm dlx` replaces `npx`.
- **Zero runtime dependencies in `core` and `python`.** Adapters may depend
  only on `@smooth-reading/core` plus their framework as a peer dependency.
- **No `innerHTML` in adapters**: framework packages render real elements from
  `tokenize()` output. `toHtml` output is for string contexts (SSR templates,
  static site generators, Markdown pipelines).
- **Presentation is CSS**: emit neutral markup (`<b>` or configurable
  tag/class); weight, colour and opacity live in `styles.css` custom
  properties.

## Scope Rules

- These root rules cover only monorepo-level constraints.
- For a task within one package, also follow that package's `README.md` API
  and keep its tests green: `pnpm --filter <name> build test typecheck`, or
  `cd python && pytest && mypy --strict smooth_reading`.
- Any change to the algorithm touches `docs/SPEC.md`, `fixtures/`, `core`
  and `python` together; all fixture tests in all ports must pass in the same
  commit.
- `AGENTS.md` is a verbatim copy of `CLAUDE.md` (for Codex and other agents).
  After editing `CLAUDE.md`, re-copy it over `AGENTS.md` in the same commit.

## Documentation Priority

- `docs/SPEC.md` — the algorithm and API contract. Read before touching
  tokenization, fixation length, HTML output or adapter APIs.
- Package `README.md` files — public API and usage; keep examples runnable.
- `docs/internal/` — research and planning notes; gitignored, never link to
  it from public docs.

## CI/CD (GitHub Actions)

- `ci.yml` — on push/PR: pnpm install (frozen lockfile), build, typecheck,
  test for all JS packages; pytest + mypy for Python on 3.10 and latest.
- Publishing is manual for now (`pnpm publish -r --access public`,
  `python -m build && twine upload`). Versions are bumped together across all
  packages; keep every package at the same version.
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
| `react` / `vue` / `svelte` / `dom` | Changes within that adapter package |
| `python` | Changes within `python/` |
| `fixtures` | Changes within `fixtures/` |
| `spec` | Changes to `docs/SPEC.md` |
| `examples` | Changes within `examples/` |
| `workspace` | Repo-root-level changes (`CLAUDE.md`, CI, root configs) |

Cross-package changes may combine scopes (`spec,core,python`).

## Directory Boundaries

- The repository root is not the root of any single package; do not place
  package-specific source or config at the root.
- Generated artifacts are never committed: `dist/`, `coverage/`,
  `node_modules/`, `python/.venv/`, `__pycache__/`, `*.egg-info/`.
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
