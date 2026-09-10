import Foundation

extension SmoothReading {

    /// Render `text` as HTML with each fixation wrapped in ``HtmlOptions/tag``
    /// (default `<b>`). Mirrors `toHtml` in `docs/SPEC.md` §4.
    ///
    /// When ``HtmlOptions/ignoreHtmlTags`` is `true` (the default):
    /// - existing tags are passed through verbatim (a `<` only starts markup
    ///   when followed by a letter, `/`, `!` or `?`; a tag ends at the first
    ///   `>`, a comment at `-->` and a CDATA section at `]]>`);
    /// - existing character references such as `&amp;` or `&#x27;` are passed
    ///   through verbatim and act as word boundaries; a bare `&` is escaped;
    /// - the contents of ``HtmlOptions/skipTags`` elements — plus the emphasis
    ///   `tag` and `restTag` themselves — are left untouched.
    ///
    /// When it is `false` the whole input is plain text and every `&`, `<`, `>`
    /// and `"` is escaped.
    public static func html(_ text: String, options: HtmlOptions = HtmlOptions()) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count + text.utf8.count / 4)
        var wordIndex = 0

        guard options.ignoreHtmlTags else {
            renderText(text, range: text.startIndex..<text.endIndex, options: options,
                       wordIndex: &wordIndex, into: &out)
            return out
        }

        // The emphasis tags themselves are always skipped, so re-running the
        // renderer over its own output never nests a second fixation inside one
        // it already produced (spec §4).
        var skipTags = Set(options.skipTags.map { $0.lowercased() })
        skipTags.insert(options.tag.lowercased())
        if let restTag = options.restTag { skipTags.insert(restTag.lowercased()) }

        var cursor = text.startIndex
        var pendingStart = text.startIndex
        var skipTag: String?
        var skipDepth = 0
        // Once a search for `>` fails, no later `<` can start a tag either
        // (`-->` and `]]>` contain one too); remembering that keeps a text full
        // of bare `<` linear.
        var noClosingBracketAhead = false

        func flushText(upTo end: String.Index) {
            guard pendingStart < end else { return }
            if skipTag == nil {
                renderText(text, range: pendingStart..<end, options: options,
                           wordIndex: &wordIndex, into: &out)
            } else {
                out += text[pendingStart..<end]  // inside a skipped element: verbatim
            }
        }

        while cursor < text.endIndex {
            switch text[cursor] {
            case "<" where !noClosingBracketAhead:
                let next = text.index(after: cursor)
                guard next < text.endIndex, startsMarkup(text[next]) else { break }
                guard let tagEnd = markupEnd(in: text, from: cursor) else {
                    noClosingBracketAhead = true
                    break
                }
                flushText(upTo: cursor)
                let raw = text[cursor..<tagEnd]
                out += raw  // tags are always verbatim
                if let tag = parseTag(raw) {
                    if let current = skipTag {
                        if tag.name == current, !tag.isSelfClosing {
                            skipDepth += tag.isClosing ? -1 : 1
                            if skipDepth <= 0 { skipTag = nil; skipDepth = 0 }
                        }
                    } else if !tag.isClosing, !tag.isSelfClosing, skipTags.contains(tag.name) {
                        skipTag = tag.name
                        skipDepth = 1
                    }
                }
                cursor = tagEnd
                pendingStart = tagEnd
                continue
            case "&":
                guard let referenceEnd = characterReferenceEnd(in: text, from: cursor) else { break }
                flushText(upTo: cursor)
                out += text[cursor..<referenceEnd]  // existing references are verbatim
                cursor = referenceEnd
                pendingStart = referenceEnd
                continue
            default:
                break
            }
            cursor = text.index(after: cursor)
        }
        flushText(upTo: text.endIndex)
        return out
    }

    private static func renderText(
        _ text: String, range: Range<String.Index>, options: HtmlOptions,
        wordIndex: inout Int, into out: inout String
    ) {
        var tokens: [SmoothToken] = []
        appendTokens(of: text, range: range, options: options.options,
                     wordIndex: &wordIndex, into: &tokens)
        for token in tokens {
            switch token {
            case let .separator(text):
                out += escapeHtml(text)
            case let .word(word, fixation, fixationText, restText):
                // A word without a fixation is plain text, never wrapped in `restTag`.
                guard fixation > 0 else {
                    out += escapeHtml(word)
                    continue
                }
                out += openTag(options.tag, className: options.className)
                out += escapeHtml(fixationText)
                out += "</\(options.tag)>"
                if let restTag = options.restTag, !restText.isEmpty {
                    out += openTag(restTag, className: options.restClassName)
                    out += escapeHtml(restText)
                    out += "</\(restTag)>"
                } else {
                    out += escapeHtml(restText)
                }
            }
        }
    }

    /// Only a `nil` class name omits the attribute; an empty string emits
    /// `class=""`, exactly like the reference `openTag` in `html.ts` (which
    /// tests `className === undefined`).
    private static func openTag(_ name: String, className: String?) -> String {
        guard let className else { return "<\(name)>" }
        return "<\(name) class=\"\(escapeHtml(className))\">"
    }

    /// Escapes the four characters the spec requires: `&`, `<`, `>`, `"`.
    static func escapeHtml(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(character)
            }
        }
        return out
    }

    // MARK: - Markup scanning

    /// Spec §4: a `<` only starts markup when followed by a letter, `/`, `!` or `?`.
    private static func startsMarkup(_ character: Character) -> Bool {
        guard let byte = character.asciiValue else { return false }
        return isAsciiLetter(byte) || byte == UInt8(ascii: "/") || byte == UInt8(ascii: "!")
            || byte == UInt8(ascii: "?")
    }

    /// Markup blocks that may contain a bare `>` (spec §4): each entry is the
    /// opener and its terminator. Mirrors `BLOCKS` in the reference lexer.
    private static let blocks: [(opener: String, terminator: String)] = [
        ("<!--", "-->"),
        ("<![CDATA[", "]]>"),
    ]

    /// Index just past the markup starting at `text[start]` (a `<` that
    /// ``startsMarkup(_:)`` accepted), or `nil` when it is unterminated.
    ///
    /// Spec §4: a tag, processing instruction or declaration ends at the
    /// **first** `>` — quoted attribute values are not parsed. A comment
    /// `<!--` ends at the first `-->` and a CDATA section `<![CDATA[` at the
    /// first `]]>`, both may contain `>`. An unterminated comment or CDATA
    /// block degrades to an ordinary `<!...>` declaration, exactly like
    /// `findTagEnd` in the reference lexer.
    static func markupEnd(in text: String, from start: String.Index) -> String.Index? {
        for block in blocks where text[start...].hasPrefix(block.opener) {
            let bodyStart = text.index(start, offsetBy: block.opener.count)
            if let close = text[bodyStart...].range(of: block.terminator) {
                return close.upperBound
            }
        }
        guard let close = text[text.index(after: start)...].firstIndex(of: ">") else { return nil }
        return text.index(after: close)
    }

    /// If `text[start]` (an `&`) begins a character reference —
    /// `&name;`, `&#123;` or `&#x1F;` — returns the index just past its `;`.
    ///
    /// Works on `Character`s, so the result is always a grapheme boundary and
    /// safe to slice with.
    static func characterReferenceEnd(in text: String, from start: String.Index) -> String.Index? {
        var index = text.index(after: start)
        guard index < text.endIndex else { return nil }
        let accepts: (UInt8) -> Bool
        if text[index] == "#" {
            index = text.index(after: index)
            guard index < text.endIndex else { return nil }
            if text[index] == "x" || text[index] == "X" {
                index = text.index(after: index)
                accepts = isAsciiHexDigit
            } else {
                accepts = isAsciiDigit
            }
        } else {
            guard let byte = text[index].asciiValue, isAsciiLetter(byte) else { return nil }
            accepts = { isAsciiLetter($0) || isAsciiDigit($0) }
        }
        let bodyStart = index
        while index < text.endIndex, let byte = text[index].asciiValue, accepts(byte) {
            index = text.index(after: index)
        }
        guard index > bodyStart, index < text.endIndex, text[index] == ";" else { return nil }
        return text.index(after: index)
    }

    private static func isAsciiLetter(_ byte: UInt8) -> Bool {
        let lower = byte | 0x20
        return lower >= UInt8(ascii: "a") && lower <= UInt8(ascii: "z")
    }

    private static func isAsciiDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    private static func isAsciiHexDigit(_ byte: UInt8) -> Bool {
        let lower = byte | 0x20
        return isAsciiDigit(byte) || (lower >= UInt8(ascii: "a") && lower <= UInt8(ascii: "f"))
    }

    /// Splits a raw tag into its lowercased name, and whether it is a closing
    /// or a self-closing tag. Returns `nil` when the markup has no tag name at
    /// all (a comment, a CDATA section, `<!DOCTYPE …>`, `<?php … ?>`), in which
    /// case the caller leaves the skip state untouched.
    ///
    /// This reproduces `TAG_NAME_RE` (`/^<\s*(\/?)\s*([a-zA-Z][^\s/>]*)/`) and
    /// the `/\/\s*>$/` self-closing test from the reference `consumeTag` in
    /// `html.ts`:
    ///
    /// - the name starts with an ASCII letter and runs to the first whitespace,
    ///   `/` or `>` — so `<code.x>` is the element `code.x`, which is *not* the
    ///   skip tag `code`;
    /// - whitespace may follow the `/` of a closing tag, so `</ code>` closes
    ///   `code`;
    /// - whitespace may precede the `>` of a self-closing tag, so `<code / >`
    ///   opens nothing.
    private static func parseTag(_ raw: Substring) -> (name: String, isClosing: Bool, isSelfClosing: Bool)? {
        var index = raw.index(after: raw.startIndex)  // past "<"
        func skipWhitespace() {
            while index < raw.endIndex, isMarkupWhitespace(raw[index]) { index = raw.index(after: index) }
        }
        skipWhitespace()
        var isClosing = false
        if index < raw.endIndex, raw[index] == "/" {
            isClosing = true
            index = raw.index(after: index)
        }
        skipWhitespace()
        guard index < raw.endIndex, let byte = raw[index].asciiValue, isAsciiLetter(byte) else {
            return nil
        }
        let nameStart = index
        index = raw.index(after: index)
        while index < raw.endIndex, raw[index] != "/", raw[index] != ">",
            !isMarkupWhitespace(raw[index])
        {
            index = raw.index(after: index)
        }
        return (raw[nameStart..<index].lowercased(), isClosing, isSelfClosing(raw))
    }

    /// `/\/\s*>$/`: a `/` followed by optional whitespace and the final `>`.
    private static func isSelfClosing(_ raw: Substring) -> Bool {
        guard raw.last == ">" else { return false }
        var index = raw.index(before: raw.endIndex)
        while index > raw.startIndex {
            let previous = raw.index(before: index)
            guard isMarkupWhitespace(raw[previous]) else { return raw[previous] == "/" }
            index = previous
        }
        return false
    }

    /// JavaScript's `\s`, so the tag grammar above matches the reference
    /// regexes character for character.
    private static func isMarkupWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x09...0x0d, 0x20, 0xa0, 0x1680, 0x2000...0x200a, 0x2028, 0x2029, 0x202f, 0x205f,
                0x3000, 0xfeff:
                return true
            default:
                return false
            }
        }
    }
}
