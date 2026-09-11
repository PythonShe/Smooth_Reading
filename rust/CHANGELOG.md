# Changelog

This crate is versioned together with every other Smooth Reading port. The
changelog for all ports lives at the repository root:
https://github.com/PythonShe/Smooth_Reading/blob/main/CHANGELOG.md

## 0.3.0

- First release of the Rust port: `tokenize`, `tokenize_with_state`,
  `to_html`, `to_markdown`, `escape_html`, `fixation_length`, `Options`,
  `HtmlOptions`, a pluggable `Segmenter` trait with the spec's `SpecSegmenter`
  as the default, a generated Unicode general-category table
  (`unicode_data`) and the `smooth-reading` CLI. Zero runtime dependencies,
  `#![forbid(unsafe_code)]`. Passes the shared `fixtures/common` suite
  byte-for-byte with the other five ports.
