import Foundation

/// ICU-backed word segmentation.
///
/// Every path goes through `CFStringTokenizer` with
/// `kCFStringTokenizerUnitWordBoundary`, the only Foundation word breaker that
/// accepts an explicit locale and therefore the only one that reliably selects
/// ICU's *dictionary* break engines for the scripts that do not use spaces
/// (Chinese, Japanese, Thai, Lao, Khmer, Burmese). This matches `docs/SPEC.md`
/// §3 and keeps the Swift port byte-identical with the TypeScript, Kotlin and
/// Python ports.
///
/// `String.enumerateSubstrings(in:options: .byWords)` is deliberately *not*
/// used: it applies plain UAX #29 word-break rules with no dictionary, so
/// `你好，世界！` came out as `你`/`好`/`世界` instead of `你好`/`世界` and
/// `日本語OKです` as `日`/`本`/`語` instead of `日本`/`語`.
///
/// When ``SmoothOptions/locale`` is `nil` the language is auto-detected (see
/// ``detectedLocale(for:range:)``) rather than defaulting to a locale with no
/// dictionary, because dictionary-based CJK breaking is the default behaviour
/// this library promises.
enum Tokenizer {
    /// Ranges of the word-like segments of `text[range]`, in order.
    static func wordRanges(in text: String, range: Range<String.Index>, locale: Locale?) -> [Range<String.Index>] {
        let resolved = locale ?? detectedLocale(for: text, range: range)
        return localeAwareWordRanges(in: text, range: range, locale: resolved)
    }

    /// The locale used when the caller supplies none.
    ///
    /// `CFStringTokenizerCopyBestStringLanguage` identifies the dominant
    /// language of the text, which is what selects the ICU dictionary engine.
    /// Passing `nil` straight to `CFStringTokenizerCreate` is *not* equivalent:
    /// it leaves Han text on the root break rules, so `你好，世界！` would split
    /// into `你` + `好`.
    ///
    /// Only the **language subtag** of the detection is kept. Script and region
    /// subtags guessed from the text itself are unreliable — Han characters
    /// shared by both Chinese scripts are frequently reported as `zh-Hant`,
    /// whose break engine splits common Simplified words (`你好` → `你` + `好`) —
    /// while the language subtag alone (`zh`) selects the same dictionary every
    /// other port uses. A caller that wants a specific variant passes an
    /// explicit ``SmoothOptions/locale``, which is never overridden here.
    ///
    /// Text with no detectable language (digits, punctuation, a lone letter)
    /// falls back to `Locale.current`.
    static func detectedLocale(for text: String, range: Range<String.Index>) -> Locale {
        let utf16Start = text.utf16.distance(from: text.startIndex, to: range.lowerBound)
        let utf16Length = text.utf16.distance(from: range.lowerBound, to: range.upperBound)
        guard
            let detected = CFStringTokenizerCopyBestStringLanguage(
                text as CFString, CFRangeMake(utf16Start, utf16Length)) as String?
        else { return .current }
        let language = detected.prefix { $0 != "-" && $0 != "_" }
        return language.isEmpty ? .current : Locale(identifier: String(language))
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
            // ICU reports UTF-16 offsets and happily ends a token in the middle
            // of a grapheme cluster: `我́` (U+6211 U+0301) comes back as the
            // token `我` plus a separate token for the combining mark. SPEC §3
            // works in grapheme clusters, so every range is widened to the
            // clusters it touches, and a widened range that overlaps the word
            // before it is merged into it instead of duplicating it.
            guard
                let lower = snappedDown(in: text, utf16Offset: cfRange.location),
                let upper = snappedUp(in: text, utf16Offset: cfRange.location + cfRange.length),
                lower < upper, isWordLike(text[lower..<upper])
            else { continue }
            if let last = ranges.last, lower < last.upperBound {
                ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, upper)
            } else {
                ranges.append(lower..<upper)
            }
        }
        return ranges
    }

    /// The grapheme-cluster boundary at or before `utf16Offset`.
    private static func snappedDown(in text: String, utf16Offset: Int) -> String.Index? {
        var offset = utf16Offset
        while offset >= 0 {
            if let index = text.utf16.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex),
                let snapped = index.samePosition(in: text)
            {
                return snapped
            }
            offset -= 1
        }
        return nil
    }

    /// The grapheme-cluster boundary at or after `utf16Offset`.
    private static func snappedUp(in text: String, utf16Offset: Int) -> String.Index? {
        var offset = utf16Offset
        while let index = text.utf16.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex) {
            if let snapped = index.samePosition(in: text) { return snapped }
            offset += 1
        }
        return nil
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
