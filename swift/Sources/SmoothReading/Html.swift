import Foundation

extension SmoothReading {

    /// Render `text` as HTML with each fixation wrapped in ``HtmlOptions/tag``
    /// (default `<b>`). Mirrors `toHtml` in `docs/SPEC.md` §4.
    ///
    /// When ``HtmlOptions/ignoreHtmlTags`` is `true` (the default) existing tags
    /// are passed through verbatim and the contents of ``HtmlOptions/skipTags``
    /// elements are left untouched. Emitted text is escaped (`&`, `<`, `>`, `"`).
    public static func html(_ text: String, options: HtmlOptions = HtmlOptions()) -> String {
        var out = ""
        var wordIndex = 0

        guard options.ignoreHtmlTags else {
            renderText(text, range: text.startIndex..<text.endIndex, options: options,
                       wordIndex: &wordIndex, into: &out)
            return out
        }

        // The emphasis tags themselves are always skipped, so re-running the
        // renderer over its own output never nests a second fixation inside one
        // it already produced (spec §4, "does not double-wrap").
        var skipTags = Set(options.skipTags.map { $0.lowercased() })
        skipTags.insert(options.tag.lowercased())
        if let restTag = options.restTag { skipTags.insert(restTag.lowercased()) }

        var cursor = text.startIndex
        var pendingStart = text.startIndex
        var skipTag: String?
        var skipDepth = 0

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
            guard text[cursor] == "<", let close = text[cursor...].firstIndex(of: ">") else {
                cursor = text.index(after: cursor)
                continue
            }
            flushText(upTo: cursor)
            let tagEnd = text.index(after: close)
            let raw = text[cursor..<tagEnd]
            out += raw  // tags are always verbatim
            let tag = parseTag(raw)
            if let current = skipTag {
                if tag.name == current, !tag.isSelfClosing {
                    skipDepth += tag.isClosing ? -1 : 1
                    if skipDepth <= 0 { skipTag = nil; skipDepth = 0 }
                }
            } else if !tag.isClosing, !tag.isSelfClosing, skipTags.contains(tag.name) {
                skipTag = tag.name
                skipDepth = 1
            }
            cursor = tagEnd
            pendingStart = tagEnd
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

    private static func openTag(_ name: String, className: String?) -> String {
        if let className, !className.isEmpty {
            return "<\(name) class=\"\(escapeHtml(className))\">"
        }
        return "<\(name)>"
    }

    /// Escapes the four characters the spec requires: `&`, `<`, `>`, `"`.
    static func escapeHtml(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
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

    private static func parseTag(_ raw: Substring) -> (name: String, isClosing: Bool, isSelfClosing: Bool) {
        var body = raw.dropFirst()  // "<"
        if body.hasSuffix(">") { body = body.dropLast() }
        let isSelfClosing = body.hasSuffix("/")
        if isSelfClosing { body = body.dropLast() }
        let isClosing = body.hasPrefix("/")
        if isClosing { body = body.dropFirst() }
        let name = body.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return (name.lowercased(), isClosing, isSelfClosing)
    }
}
