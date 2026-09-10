import Foundation

/// ICU-backed word segmentation.
///
/// Primary implementation: `String.enumerateSubstrings(in:options: .byWords)`,
/// which uses ICU's default word-break rules — apostrophes join (`don't` is one
/// word), hyphens split (`well-known` is two), and CJK/Thai get dictionary-based
/// breaks. This matches `docs/SPEC.md` §3.
///
/// When ``SmoothOptions/locale`` is set, `CFStringTokenizer` is used instead
/// because it is the only Foundation word breaker that accepts an explicit
/// locale; it produces the same word boundaries for every `common` fixture.
enum Tokenizer {
    /// Ranges of the word-like segments of `text[range]`, in order.
    static func wordRanges(in text: String, range: Range<String.Index>, locale: Locale?) -> [Range<String.Index>] {
        if let locale {
            return localeAwareWordRanges(in: text, range: range, locale: locale)
        }
        var ranges: [Range<String.Index>] = []
        text.enumerateSubstrings(in: range, options: [.byWords]) { _, wordRange, _, _ in
            // `.byWords` occasionally reports a bare separator as a word (a
            // space between a Latin brand name and digits inside Chinese text,
            // for example); the CFStringTokenizer path applies the same filter.
            guard isWordLike(text[wordRange]) else { return }
            ranges.append(wordRange)
        }
        return ranges
    }

    private static func localeAwareWordRanges(
        in text: String, range: Range<String.Index>, locale: Locale
    ) -> [Range<String.Index>] {
        let cf = text as CFString
        let utf16Start = text.utf16.distance(from: text.startIndex, to: range.lowerBound)
        let utf16Length = text.utf16.distance(from: range.lowerBound, to: range.upperBound)
        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault, cf, CFRangeMake(utf16Start, utf16Length),
            kCFStringTokenizerUnitWordBoundary, locale as CFLocale)
        var ranges: [Range<String.Index>] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let cfRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard cfRange.location != kCFNotFound, cfRange.length > 0 else { continue }
            guard
                let lower = text.utf16.index(
                    text.startIndex, offsetBy: cfRange.location, limitedBy: text.endIndex),
                let upper = text.utf16.index(lower, offsetBy: cfRange.length, limitedBy: text.endIndex),
                let sLower = lower.samePosition(in: text), let sUpper = upper.samePosition(in: text)
            else { continue }
            let token = text[sLower..<sUpper]
            if isWordLike(token) { ranges.append(sLower..<sUpper) }
        }
        return ranges
    }

    /// A segment is word-like when it contains a letter or a number (`\p{L}`,
    /// `\p{N}`) — the classes that may start a word in the spec's regex
    /// fallback. Combining marks alone never make a word: `CFStringTokenizer`
    /// reports the variation selector of `❤️` as its own token, and that must
    /// stay a separator (SPEC §3, UAX #29 WB4).
    private static func isWordLike(_ token: Substring) -> Bool {
        token.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                .decimalNumber, .letterNumber, .otherNumber:
                return true
            default:
                return false
            }
        }
    }
}
