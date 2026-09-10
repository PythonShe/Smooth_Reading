import Foundation

/// Guided fixation reading: emphasise the leading grapheme clusters of each
/// word so the eye gets an artificial fixation point.
///
/// The algorithm is specified in `docs/SPEC.md` and is byte-identical across
/// every port of this project.
public enum SmoothReading {

    // MARK: - Fixation length (spec §2)

    /// The §2 ratio table (0.20 … 0.80) as integer percentages, so the
    /// rounding below never depends on floating-point representation.
    private static let percents = [20, 35, 50, 65, 80]

    /// Number of grapheme clusters to emphasise for `word`.
    ///
    /// - Parameters:
    ///   - word: the word text.
    ///   - graphemes: the word's grapheme-cluster count (`word.count`).
    ///   - options: resolved options.
    /// - Returns: a value in `0...graphemes`; `0` means "no fixation".
    public static func fixationLength(word: String, graphemes: Int, options: SmoothOptions = .default) -> Int {
        if let override = options.fixationLength {
            return min(max(override(word, graphemes, options), 0), graphemes)
        }
        guard graphemes > 0 else { return 0 }
        // Suppression rules first: an all-digit word or a word below
        // `minWordLength` is never emphasised, whatever its length.
        if !options.emphasizeNumbers, isAllDigits(word) { return 0 }
        if graphemes < options.minWordLength { return 0 }
        // A single character is emphasised only at strength >= 3.
        if graphemes == 1 { return options.clampedFixation >= 3 ? 1 : 0 }
        let percent = percents[options.clampedFixation - 1]
        return min(max(roundHalfUp(graphemes: graphemes, percent: percent), 1), graphemes)
    }

    /// Spec §2 `round_half_up(n * ratio)` = `floor(n * ratio + 0.5)`, computed
    /// as `floor((n * percent + 50) / 100)` in integer arithmetic. Never
    /// banker's rounding, and no floating-point drift (`3 * 0.35` is
    /// `1.0499…` as a `Double`), so every port agrees.
    static func roundHalfUp(graphemes: Int, percent: Int) -> Int {
        (graphemes * percent + 50) / 100
    }

    static func isAllDigits(_ word: String) -> Bool {
        !word.isEmpty && word.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    // MARK: - Tokenize (spec §3/§4)

    /// Split `text` into word and separator tokens, computing each word's
    /// fixation split.
    ///
    /// Separator runs between words are returned as single tokens, so
    /// concatenating every token's `text` reproduces the input exactly.
    public static func tokenize(_ text: String, options: SmoothOptions = .default) -> [SmoothToken] {
        var tokens: [SmoothToken] = []
        var wordIndex = 0
        appendTokens(of: text, range: text.startIndex..<text.endIndex, options: options,
                     wordIndex: &wordIndex, into: &tokens)
        return tokens
    }

    /// Tokenizes `text[range]`, continuing the saccade counter in `wordIndex`.
    static func appendTokens(
        of text: String,
        range: Range<String.Index>,
        options: SmoothOptions,
        wordIndex: inout Int,
        into tokens: inout [SmoothToken]
    ) {
        guard range.lowerBound < range.upperBound else { return }
        let saccade = options.clampedSaccade
        var cursor = range.lowerBound
        for wordRange in Tokenizer.wordRanges(in: text, range: range, locale: options.locale) {
            if cursor < wordRange.lowerBound {
                tokens.append(.separator(text: String(text[cursor..<wordRange.lowerBound])))
            }
            let word = String(text[wordRange])
            let graphemes = word.count
            // `saccade` counts word tokens only; index 0 always gets a fixation.
            let emphasise = wordIndex % saccade == 0
            wordIndex += 1
            let length = emphasise ? fixationLength(word: word, graphemes: graphemes, options: options) : 0
            let prefix = String(word.prefix(length))
            let rest = String(word.dropFirst(length))
            tokens.append(.word(text: word, fixation: length, fixationText: prefix, restText: rest))
            cursor = wordRange.upperBound
        }
        if cursor < range.upperBound {
            tokens.append(.separator(text: String(text[cursor..<range.upperBound])))
        }
    }
}
