import Foundation

/// Options controlling how text is split into words and how much of each word
/// is emphasised. Mirrors `SmoothOptions` in `docs/SPEC.md` §4.
public struct SmoothOptions: Sendable {
    /// Fixation strength, 1...5. Values outside the range are clamped. Default `3`.
    public var fixation: Int
    /// Which words get a fixation: `1` = every word, `2` = every second word, ... Default `1`.
    public var saccade: Int
    /// Words shorter than this (in grapheme clusters) get no fixation. Default `1`.
    public var minWordLength: Int
    /// Emphasise words consisting entirely of digits. Default `false`.
    public var emphasizeNumbers: Bool
    /// Locale handed to the ICU word breaker. `nil` → the runtime default.
    public var locale: Locale?
    /// Optional override replacing the fixation-length algorithm entirely.
    /// Receives the word, its grapheme count and the resolved options; the
    /// returned value is clamped to `0...graphemes`.
    public var fixationLength: (@Sendable (String, Int, SmoothOptions) -> Int)?

    /// Creates options; every parameter defaults to the spec default.
    public init(
        fixation: Int = 3,
        saccade: Int = 1,
        minWordLength: Int = 1,
        emphasizeNumbers: Bool = false,
        locale: Locale? = nil,
        fixationLength: (@Sendable (String, Int, SmoothOptions) -> Int)? = nil
    ) {
        self.fixation = fixation
        self.saccade = saccade
        self.minWordLength = minWordLength
        self.emphasizeNumbers = emphasizeNumbers
        self.locale = locale
        self.fixationLength = fixationLength
    }

    /// The spec defaults: fixation 3, saccade 1, minWordLength 1, numbers off.
    public static let `default` = SmoothOptions()

    /// `fixation` clamped into the documented 1...5 range.
    var clampedFixation: Int { min(max(fixation, 1), 5) }
    /// `saccade` clamped to >= 1.
    var clampedSaccade: Int { max(saccade, 1) }
}

/// Options for ``SmoothReading/SmoothReading/html(_:options:)``. Mirrors
/// `HtmlOptions` in `docs/SPEC.md` §4, which extends `SmoothOptions`.
public struct HtmlOptions: Sendable {
    /// Tokenizer / fixation options.
    public var options: SmoothOptions
    /// Tag wrapping the fixation. Default `"b"`.
    public var tag: String
    /// Class attribute for the fixation tag. Default `nil` → no class attribute.
    public var className: String?
    /// Tag wrapping the rest of the word. Default `nil` → rest is plain text.
    public var restTag: String?
    /// Class attribute for the rest tag.
    public var restClassName: String?
    /// When `true` (default) text inside `<...>` is passed through verbatim.
    public var ignoreHtmlTags: Bool
    /// Element names (case-insensitive) whose contents are never emphasised.
    /// ``tag`` and ``restTag`` are always skipped as well, so output is never
    /// wrapped twice. Only consulted when ``ignoreHtmlTags`` is `true`.
    public var skipTags: Set<String>

    /// `["code", "pre", "script", "style", "kbd", "samp", "textarea"]`.
    public static let defaultSkipTags: Set<String> = [
        "code", "pre", "script", "style", "kbd", "samp", "textarea",
    ]

    /// Creates HTML options; every parameter defaults to the spec default.
    public init(
        options: SmoothOptions = .default,
        tag: String = "b",
        className: String? = nil,
        restTag: String? = nil,
        restClassName: String? = nil,
        ignoreHtmlTags: Bool = true,
        skipTags: Set<String> = HtmlOptions.defaultSkipTags
    ) {
        self.options = options
        self.tag = tag
        self.className = className
        self.restTag = restTag
        self.restClassName = restClassName
        self.ignoreHtmlTags = ignoreHtmlTags
        self.skipTags = skipTags
    }
}
