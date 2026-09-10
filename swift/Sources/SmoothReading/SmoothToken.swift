import Foundation

/// A piece of the input: a word with its computed fixation split, or a separator.
/// Mirrors `Token` in `docs/SPEC.md` §4.
public enum SmoothToken: Sendable, Equatable {
    /// A word token.
    /// - Parameters:
    ///   - text: the whole word.
    ///   - fixation: length of the emphasised prefix, in grapheme clusters (`0` = not emphasised).
    ///   - fixationText: the emphasised prefix (empty when `fixation == 0`).
    ///   - restText: the remainder of the word.
    case word(text: String, fixation: Int, fixationText: String, restText: String)
    /// Anything that is not a word: whitespace, punctuation, HTML tags.
    case separator(text: String)

    /// The raw text of the token, so that concatenating all tokens rebuilds the input.
    public var text: String {
        switch self {
        case let .word(text, _, _, _): return text
        case let .separator(text): return text
        }
    }
}
