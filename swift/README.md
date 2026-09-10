# SmoothReading (Swift)

Guided fixation reading for Apple platforms: the leading letters of every word are emphasised so the eye lands on an artificial fixation point and the brain completes the rest of the word.

Similar to commercial fixation-reading products, this package is an independent, clean-room, zero-dependency, Apache-2.0 library implemented strictly against the project [specification](../docs/SPEC.md) to guarantee identical output across all platforms.

- **Zero third-party dependencies**: Built exclusively on Foundation (ICU word breaking, `AttributedString`, `FontDescriptor`).
- **Swift 6 & Strict Concurrency**: All public types conform to `Sendable`.
- **Broad platform support**: iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, and visionOS 1+ (the `AttributedString` floor; the UIKit/AppKit API itself needs nothing newer).
- **UIKit & AppKit first**: `NSAttributedString` using real bold font descriptors is the primary API; `AttributedString` for SwiftUI is a first-class convenience built on the same token walk.

Every code snippet below is verified by `Tests/SmoothReadingTests/ReadmeSnippetTests.swift`.

---

## Installation

### Swift Package Manager

In Xcode, select **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/PythonShe/Smooth_Reading.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/PythonShe/Smooth_Reading.git", from: "0.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SmoothReading", package: "Smooth_Reading")
    ])
]
```

The Swift package source is located in the `swift/` directory of the monorepo, and releases are tagged `vX.Y.Z`. Because SwiftPM requires a `Package.swift` at the repository root, a root manifest exposes the `SmoothReading` library directly. When working locally across repositories, you can add it as a local path dependency: `.package(path: "../smooth_reading")`.

---

## Usage

### UIKit

`SmoothReading.nsAttributedString(_:options:font:fixationAttributes:restAttributes:)` derives a genuine bold typeface from your base font (via font descriptor traits, falling back to a bold weight for typeface families without a dedicated bold face). `UILabel`, `UITextView`, and related views render the result without bridging overhead:

```swift
import UIKit
import SmoothReading

let article = "Smooth reading works."

let label = UILabel()
label.numberOfLines = 0
label.font = .preferredFont(forTextStyle: .body)
label.attributedText = SmoothReading.nsAttributedString(
    article,
    options: SmoothOptions(fixation: 3),
    font: label.font
)

// Or the one-line convenience, which reuses the view's current font:
label.applySmoothReading(article)

let textView = UITextView()
textView.applySmoothReading(article, options: SmoothOptions(fixation: 4, saccade: 2))
```

To customize styling beyond bold (such as color, underline, or a specific typeface weight):

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

---

### AppKit

AppKit uses the same `nsAttributedString` API; bold faces are resolved via `NSFontManager` with an automatic weight fallback:

```swift
import AppKit
import SmoothReading

let article = "Smooth reading works."

let field = NSTextField(labelWithString: "")
field.attributedStringValue = SmoothReading.nsAttributedString(article, font: field.font)

// Convenience setters on NSTextField and NSTextView:
field.applySmoothReading(article)

let textView = NSTextView()
textView.applySmoothReading(article, options: SmoothOptions(fixation: 4))
```

---

### SwiftUI

`SmoothReading.attributedString(_:options:fixationAttributes:restAttributes:)` assigns `.inlinePresentationIntent = .stronglyEmphasized` to fixations, which SwiftUI's `Text` renders as bold text. It walks the exact same token stream as `nsAttributedString`:

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

Custom attributes can be applied using `AttributeContainer`:

```swift
struct TintedArticleView: View {
    let article: String

    var body: some View {
        var fixation = AttributeContainer()
        fixation.foregroundColor = .accentColor
        fixation.inlinePresentationIntent = .stronglyEmphasized

        var rest = AttributeContainer()
        rest.foregroundColor = .secondary

        return Text(
            SmoothReading.attributedString(article, fixationAttributes: fixation, restAttributes: rest)
        )
    }
}
```

---

### HTML and tokens

```swift
SmoothReading.html("Smooth reading works.")
// <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.

SmoothReading.html(
    "Smooth reading",
    options: HtmlOptions(
        options: SmoothOptions(fixation: 4),
        tag: "span", className: "sr-fixation",
        restTag: "span", restClassName: "sr-rest"
    )
)
// <span class="sr-fixation">Smoo</span><span class="sr-rest">th</span> …

// Existing markup and character references pass through untouched:
SmoothReading.html("<p>Tom &amp; <code>Jerry</code></p>")
// <p><b>To</b>m &amp; <code>Jerry</code></p>

for token in SmoothReading.tokenize("Smooth reading") {
    switch token {
    case let .word(text, fixation, fixationText, restText):
        print(text, fixation, fixationText, restText)
    case let .separator(text):
        print("sep", text)
    }
}
```

Styling classes match `packages/core/styles.css`. Emphasis remains purely presentational, emitting clean semantic markup.

---

## Configuration options

### Algorithm options (`SmoothOptions`)

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `fixation` | `Int` (1…5) | `3` | Fixation strength: ratios `0.20 / 0.35 / 0.50 / 0.65 / 0.80`, rounded half up and clamped to `1…n`. Values outside `1…5` are automatically clamped. |
| `saccade` | `Int` (≥ 1) | `1` | Emphasises every *n*-th word (`1` = every word, `2` = every second word). Word tokens consume an index, including numbers and short words. Values `< 1` are clamped to `1`. |
| `minWordLength` | `Int` | `1` | Words with fewer grapheme clusters receive no fixation. |
| `emphasizeNumbers` | `Bool` | `false` | Whether words composed entirely of decimal digits are emphasised. |
| `locale` | `Locale?` | `nil` | Locale used for word breaking. `nil` defaults to `String.enumerateSubstrings(.byWords)`; specifying a locale activates `CFStringTokenizer`, which provides dictionary breaking for Chinese, Japanese, and Thai. |
| `fixationLength` | `(@Sendable (String, Int, SmoothOptions) -> Int)?` | `nil` | Closure replacing the fixation algorithm entirely. Receives the word, its grapheme count, and options; result is clamped to `0…n`. |

### HTML options (`HtmlOptions`)

`HtmlOptions` wraps `SmoothOptions` in its `options` property and adds:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `tag` | `String` | `"b"` | Tag name wrapping each fixation prefix. |
| `className` | `String?` | `nil` | Optional `class` attribute on the fixation tag. |
| `restTag` | `String?` | `nil` | Optional tag name wrapping the remainder of the word; `nil` leaves it as plain text. |
| `restClassName` | `String?` | `nil` | Optional `class` attribute on the rest tag. |
| `ignoreHtmlTags` | `Bool` | `true` | Preserves existing tags and character references (`&amp;`, `&#x27;`). When `false`, treats input as plain text and escapes all HTML characters. |
| `skipTags` | `Set<String>` | `code`, `pre`, `script`, `style`, `kbd`, `samp`, `textarea` | Tag names whose contents are never emphasised. Fixation and rest tags are automatically skipped to avoid nested markup. |

---

## Word breaking & Multilingual support

Word boundaries are derived from ICU via `String.enumerateSubstrings(in:options: .byWords)`, or `CFStringTokenizer` when a custom `locale` is provided. Contractions join (`don't` is one word), hyphens split (`well-known` is two words), and scripts without spaces (CJK and Thai) receive dictionary-based segmentation.

Grapheme clusters are counted natively using Swift's standard library (`String.count`), adhering to Unicode UAX #29 extended grapheme cluster rules:
- Combining marks and diacritics never split from their base letters.
- Decomposed Hangul jamo compose into unified syllables.
- Indic conjuncts such as `क्ष` form single clusters (Unicode 15.1 GB9c).

### Script recommendations

- **Traditional Chinese with locale**: When passing an explicit locale to `CFStringTokenizer`, use `Locale(identifier: "zh-Hant")` (or `nil`). Standard `zh` may separate multi-character words like `我們` and `學習`.
- **Typographic considerations for Arabic and Indic scripts**: Because many fonts lack distinct bold faces or blur ligatures under bold weights, pass custom color or underline attributes via `fixationAttributes`:

  ```swift
  let attributed = SmoothReading.nsAttributedString(
      text,
      fixationAttributes: [.foregroundColor: UIColor.systemBlue] // NSColor on macOS
  )
  ```

- **Bidirectional text (RTL)**: Arabic and Hebrew are emphasised at their logical beginning (the right edge) without requiring special tags or bidi overrides. Attributed strings and HTML output do not insert isolates or directional marks.

For details on cross-engine compatibility, see [docs/LANGUAGES.md](../docs/LANGUAGES.md).

---

## Development

```sh
cd swift
swift build
swift test
```

---

## License

Apache-2.0. See [LICENSE](LICENSE).
