# Smooth Reading

Open-source, framework-friendly **guided fixation reading**: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

```
Smooth reading works.   →   **Smo**oth **read**ing **wor**ks.
```

The technique is similar to commercial fixation-reading products, but this project is independent, clean-room, trademark-free and licensed under Apache-2.0. The algorithm is documented in full in [docs/SPEC.md](docs/SPEC.md) so every port produces identical output.

## Packages

| Package | Registry | Platforms |
| --- | --- | --- |
| [`@smooth-reading/core`](packages/core) | npm | Web, Node, React Native. Zero-dependency tokenizer, HTML transformer, DOM applier, streaming transform. |
| [`SmoothReading`](swift) | Swift Package Manager | iOS, macOS. `NSAttributedString` for UIKit/AppKit, `AttributedString` for SwiftUI. |
| [`io.smoothreading:smooth-reading`](android) | Maven Central | Android, JVM. `AnnotatedString` for Compose, `Spanned` for views. |
| [`smooth-reading`](python) | PyPI | Python 3.10+. Same algorithm plus a CLI. |

React, Vue, Svelte, Angular and other framework wrappers are a few lines on top of `tokenize()`; copy one from [docs/recipes](docs/recipes) rather than adding a dependency.

## Quick start

```bash
pnpm add @smooth-reading/core
```

```ts
import { toHtml } from "@smooth-reading/core";

toHtml("Smooth reading works.");
// '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.'

toHtml("Smooth reading works.", { fixation: 5, saccade: 2, tag: "span", className: "sr-fixation" });
```

React (see [docs/recipes/react.md](docs/recipes/react.md)):

```tsx
import { tokenize } from "@smooth-reading/core";

export function SmoothText({ children, ...opts }) {
  return tokenize(children, opts).map((t, i) =>
    t.type === "word" ? <span key={i}><b>{t.fixationText}</b>{t.restText}</span> : t.text);
}
```

Swift (UIKit):

```swift
import SmoothReading
label.attributedText = SmoothReading.nsAttributedString("Smooth reading works.", options: .init(fixation: 3))
```

See each package README for the full API.

## Why another library?

Existing open-source implementations are either single-purpose string transformers, archived browser extensions, or GPL/AGPL licensed. None of them segment Chinese, Japanese or Thai correctly, keep contractions intact, render without `innerHTML`, or ship framework adapters. 

## What the evidence says

Controlled studies (Readwise 2022, Snell 2024, Možina et al. 2025) found **no reading-speed benefit** from this technique for the general population, and no controlled study has demonstrated a benefit for ADHD or dyslexic readers. Many people nevertheless report that they prefer reading this way. Treat it as a reading *preference* you can offer users, not a speed-reading feature. Sources:

- Readwise reader study, 2022, about 1,900 participants: [blog.readwise.io](https://blog.readwise.io/bionic-reading-results/).
- Snell, *Acta Psychologica* (2024): [sciencedirect.com](https://www.sciencedirect.com/science/article/pii/S0001691824001811).
- Možina, Kovačević & Blaznik, *SAGE Open* (2025), [doi:10.1177/21582440251376158](https://journals.sagepub.com/doi/10.1177/21582440251376158).
- *Attention, Perception & Psychophysics* (2025), [doi:10.3758/s13414-025-03067-w](https://link.springer.com/article/10.3758/s13414-025-03067-w).

## Design principles

- **One documented algorithm**, shared JSON fixtures, identical output across languages.
- **Unicode first**: `Intl.Segmenter` word breaking for CJK and Thai, grapheme-cluster counting, works with any script.
- **Safe by default**: skips `code`, `pre`, `kbd`, `script`, `style` and form fields; never uses `innerHTML` in framework adapters; escapes emitted text.
- **Presentation is CSS**: the transform emits neutral markup; weight, colour and opacity live in a stylesheet you control.
- **No runtime dependencies, no network, no telemetry.**

## Development

```bash
pnpm install
pnpm build
pnpm test
cd python && python -m pip install -e ".[dev]" && pytest
```

## License

Apache-2.0. See [LICENSE](LICENSE).
