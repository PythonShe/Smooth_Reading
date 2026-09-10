# SmoothReading (Swift)

Guided fixation reading for Apple platforms: the leading letters of every word
are emphasised so the eye gets an artificial fixation point and the brain
completes the rest of the word. Similar to commercial fixation-reading products,
but open source, dependency-free and specified in
[`docs/SPEC.md`](../docs/SPEC.md) so every port of this project produces
identical output.

- Zero dependencies — Foundation only (ICU word breaking, `AttributedString`).
- Swift 6, strict concurrency: every public type is `Sendable`.
- iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+.

## Install

Swift Package Manager — in Xcode, *File ▸ Add Package Dependencies…* and point
at this repository, or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/smooth-reading.git", from: "0.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SmoothReading", package: "smooth-reading")
    ])
]
```

The package manifest lives in the `swift/` directory of the monorepo and
releases are tagged `vX.Y.Z`. Because SPM resolves a package from the root of a
repository, distribution is done from a repository whose root is this directory
(a published mirror of `swift/`); to try it locally, add it as a path
dependency: `.package(path: "../smooth_reading/swift")`.

## UIKit

`nsAttributedString(_:options:font:fixationAttributes:restAttributes:)` derives a
real bold font from the base font, so `UILabel`, `UITextView` and friends render
it without any bridging surprises.

```swift
import UIKit
import SmoothReading

let label = UILabel()
label.numberOfLines = 0
label.font = .preferredFont(forTextStyle: .body)
label.attributedText = SmoothReading.nsAttributedString(
    "Smooth reading works.",
    options: SmoothOptions(fixation: 3),
    font: label.font
)

// Or the one-line convenience, which reuses the view's current font:
label.applySmoothReading("Smooth reading works.")

let textView = UITextView()
textView.applySmoothReading(article, options: SmoothOptions(fixation: 4, saccade: 2))
```

Custom emphasis instead of bold (colour, underline, a different face):

```swift
label.attributedText = SmoothReading.nsAttributedString(
    "Smooth reading works.",
    font: label.font,
    fixationAttributes: [
        .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: UIColor.label,
    ],
    restAttributes: [
        .font: UIFont.systemFont(ofSize: 17, weight: .regular),
        .foregroundColor: UIColor.secondaryLabel,
    ]
)
```

## AppKit

```swift
import AppKit
import SmoothReading

let field = NSTextField(labelWithString: "")
field.attributedStringValue = SmoothReading.nsAttributedString(
    "Smooth reading works.",
    font: field.font
)

// Convenience setters on NSTextField and NSTextView:
field.applySmoothReading("Smooth reading works.")
textView.applySmoothReading(article, options: SmoothOptions(fixation: 4))
```

## SwiftUI

`attributedString(_:options:fixation:rest:)` marks fixations with
`.inlinePresentationIntent = .stronglyEmphasized`, which `Text` renders bold.

```swift
import SwiftUI
import SmoothReading

struct ArticleView: View {
    let article: String

    var body: some View {
        Text(SmoothReading.attributedString(article, options: SmoothOptions(fixation: 3)))
            .font(.body)
    }
}
```

Pass your own containers for a different look:

```swift
var fixation = AttributeContainer()
fixation.foregroundColor = .accentColor
fixation.inlinePresentationIntent = .stronglyEmphasized

var rest = AttributeContainer()
rest.foregroundColor = .secondary

Text(SmoothReading.attributedString(article, fixation: fixation, rest: rest))
```

## HTML and tokens

```swift
SmoothReading.html("Smooth reading works.")
// <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.

SmoothReading.html(
    "Smooth reading",
    options: HtmlOptions(
        tag: "span", className: "sr-fixation",
        restTag: "span", restClassName: "sr-rest"
    )
)
// <span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> …

for token in SmoothReading.tokenize("Smooth reading") {
    switch token {
    case let .word(text, fixation, fixationText, restText):
        print(text, fixation, fixationText, restText)
    case let .separator(text):
        print("sep", text)
    }
}
```

Styling for the HTML output lives in `packages/core/styles.css`; emphasis is
purely presentational, so the library only emits neutral markup.

## Options

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fixation` | `Int` (1…5) | `3` | How much of each word is emphasised: ratios 0.20 / 0.35 / 0.50 / 0.65 / 0.80, rounded half up and clamped to `1…n`. Values outside 1…5 are clamped. |
| `saccade` | `Int` (≥ 1) | `1` | `1` emphasises every word, `2` every second word, … Counts word tokens only; the first word always gets a fixation, and numbers consume an index even when not emphasised. |
| `minWordLength` | `Int` | `1` | Words shorter than this (in grapheme clusters) get no fixation. |
| `emphasizeNumbers` | `Bool` | `false` | Emphasise words made entirely of digits. |
| `locale` | `Locale?` | `nil` | Locale for word breaking. `nil` uses `String.enumerateSubstrings(.byWords)`; a locale switches to `CFStringTokenizer` with that locale, which matters for Chinese, Japanese and Thai. |
| `fixationLength` | `(@Sendable (String, Int, SmoothOptions) -> Int)?` | `nil` | Replaces the algorithm entirely. Receives the word, its grapheme count and the options; the result is clamped to `0…n`. |

`HtmlOptions` wraps a `SmoothOptions` in its `options` property and adds:

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tag` | `String` | `"b"` | Tag wrapping each fixation. |
| `className` | `String?` | `nil` | Class attribute on the fixation tag. |
| `restTag` | `String?` | `nil` | Tag wrapping the rest of the word; `nil` leaves it plain text. |
| `restClassName` | `String?` | `nil` | Class attribute on the rest tag. |
| `ignoreHtmlTags` | `Bool` | `true` | Pass existing `<…>` tags through verbatim instead of escaping them. |
| `skipTags` | `Set<String>` | `code`, `pre`, `script`, `style`, `kbd`, `samp`, `textarea` | Elements whose text is never emphasised. `tag` and `restTag` are always skipped as well, so output is never wrapped twice. |

## Word breaking

Words come from ICU via `String.enumerateSubstrings(in:options: .byWords)`:
apostrophes join (`don't` is one word), hyphens split (`well-known` is two), and
CJK/Thai get dictionary-based breaks. Grapheme clusters are counted natively
(`String.count`), so combining marks are never split from their base and a
single-scalar count is never used.

This port passes both `fixtures/common/*.json` and `fixtures/segmenter/*.json`.

## Development

```sh
cd swift
swift build
swift test
```

## License

Apache-2.0 © Smooth Reading contributors.
