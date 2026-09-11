# Contributing

## External pull requests are not accepted for now

This project does **not** accept external pull requests at the moment. Pull
requests from outside the project will be closed without review. What is
welcome:

- **Issues and discussions** — bug reports (a failing fixture is ideal),
  language and script problems, questions about the spec.
- **Forks** — the code is Apache-2.0; fork it, change it, ship it.

The rest of this page is for people working from a fork or maintaining the
project: it describes how the suites run and the rules that keep the six
ports in lockstep.

Smooth Reading is one documented algorithm (`docs/SPEC.md`) with six
first-party ports that must produce identical output.

## Running the test suites

Every change must leave all six suites green. From the repository root:

```bash
# TypeScript core (packages/core)
pnpm install && pnpm build && pnpm test

# Swift package
cd swift && swift test

# Android / Kotlin
cd android && ./gradlew test

# Python package
cd python && python -m pip install -e ".[dev]" && pytest && mypy --strict smooth_reading

# Dart package
cd dart && dart pub get && dart analyze && dart test

# Rust crate
cd rust && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test
```

`pnpm typecheck` runs the TypeScript type check on its own, and `swift test`
also works from the repository root (the root `Package.swift` declares the
same targets as `swift/Package.swift`).

## The spec, the fixtures and the ports move together

`docs/SPEC.md` owns the rules: the fixation ratio table, round-half-up, saccade
counting, the tokenizer, HTML escaping and option handling. Code follows the
spec, never the other way round.

Any change to the algorithm or its public options touches, in the same
commit:

1. `docs/SPEC.md`;
2. `fixtures/` (`common/` must pass in every port, `segmenter/` wherever an
   ICU word breaker exists);
3. all six ports — `packages/core/`, `swift/`, `android/`, `python/`,
   `dart/`, `rust/` — with their fixture tests passing.

If an implementation needs a rule the spec lacks, add it to the spec first.
A change that breaks a CJK, Indic, Thai, RTL or grapheme-cluster fixture is a
release blocker.

Framework adapters (React, Vue, Svelte, Angular, …) are copy-paste recipes in
`docs/recipes/`, never published packages. Recipes render real elements from
`tokenize()`; `toHtml()` output is for string contexts only.

## Commit messages

```
<type>(<scope>): <description>
```

`type` is one of `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `perf`,
`style`. `scope` is one of `core`, `swift`, `android`, `python`, `dart`, `rust`, `recipes`,
`fixtures`, `spec`, `examples`, `workspace`; cross-package changes combine
scopes (`spec,core,python`). Do not add generated-by or co-author footers.

## Naming policy

The commercial product this technique is known by is a registered trademark.
Never use that name in code, package names, keywords, identifiers, commit
messages, docs, demo copy or the website; the only permitted mention is the
neutral README sentence "similar to commercial fixation-reading products".
Do not copy, subset or bundle third-party fonts, and do not wrap or proxy any
commercial API. Do not claim ADHD, dyslexia or speed-reading benefits; cite
the published studies neutrally as the root README does.

## No personal information

Public-facing files (READMEs, docs, examples, demo copy) carry no personal
names or e-mail addresses. The owner's GitHub handle appears only where it is
required: the `Copyright` line of the `LICENSE` files and the author fields of
package metadata.

## Housekeeping

- pnpm only (`pnpm-lock.yaml` is the lockfile; `pnpm dlx` replaces `npx`).
- Zero runtime dependencies in every port; platform APIs are fine.
- Generated artifacts (`dist/`, `.build/`, `build/`, `.venv/`, `node_modules/`,
  `target/`) are never committed; `rust/Cargo.lock` is.
- Versions are bumped together across all ports and releases are tagged
  `vX.Y.Z`. Push the tag, then run
  `gh workflow run release.yml --ref vX.Y.Z -f tag=vX.Y.Z`.
  The workflow publishes `@smooth-reading/core` to npm, `smooth-reading` to
  PyPI (trusted publishing), `smooth_reading` to pub.dev (automated
  publishing), `smooth-reading` to crates.io (`CARGO_REGISTRY_TOKEN`
  secret), `io.github.pythonshe:smooth-reading` and
  `smooth-reading-core` to Maven Central,
  and creates the GitHub release that SwiftPM resolves. Prerelease tags
  (`-rc.N`, `-beta.N`) land under npm's `next` dist-tag and as PyPI
  pre-releases (`0.1.0rc1` spelling).
