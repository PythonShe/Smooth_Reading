package io.smoothreading

/**
 * Stateful HTML renderer (SPEC §4). Everything that must survive across the
 * pieces of one input lives here: the tokenize state (saccade counter) and
 * the "am I inside a skipped element?" bookkeeping.
 *
 * All output goes through a single [StringBuilder]; the only per-piece
 * allocations are the substrings handed to the segmenter.
 */
internal class HtmlRenderer(
    private val options: HtmlOptions,
    private val segmenter: WordSegmenter,
) {
    private val state = TokenizeState(options.smooth.locale)

    /** Lower-cased `skipTags` plus the emphasis tags themselves (SPEC §4). */
    private val skip: Set<String> = HashSet<String>().apply {
        options.skipTags.forEach { add(it.lowercase()) }
        add(options.tag.lowercase())
        options.restTag?.let { add(it.lowercase()) }
    }

    private var skipName: String? = null
    private var skipDepth = 0

    fun render(text: String): String {
        if (text.isEmpty()) return ""
        val out = StringBuilder(text.length + text.length / 4)
        if (!options.ignoreHtmlTags) {
            renderText(text, 0, text.length, out)
            return out.toString()
        }

        var cursor = 0
        var i = 0
        val n = text.length
        while (i < n) {
            val ch = text[i]
            if (ch != '<' && ch != '&') {
                i += 1
                continue
            }
            val end = if (ch == '<') Markup.tagEnd(text, i) else Markup.entityEnd(text, i)
            if (end < 0) {
                // Not markup (`a < b`, unterminated `<p`, bare `&`): plain text.
                i += 1
                continue
            }
            renderText(text, cursor, i, out)
            out.append(text, i, end) // verbatim
            if (ch == '<') consumeTag(text.substring(i, end))
            cursor = end
            i = end
        }
        renderText(text, cursor, n, out)
        return out.toString()
    }

    /** Tokenize and render `text[start, end)`, or pass it through inside a skipped element. */
    private fun renderText(text: String, start: Int, end: Int, out: StringBuilder) {
        if (start >= end) return
        if (skipName != null) {
            out.append(text, start, end)
            return
        }
        val piece = if (start == 0 && end == text.length) text else text.substring(start, end)
        for (token in SmoothReading.tokenize(piece, options.smooth, segmenter, state)) {
            renderToken(token, out)
        }
    }

    private fun renderToken(token: SmoothToken, out: StringBuilder) {
        val word = token as? SmoothToken.Word
        if (word == null || word.fixation == 0) {
            // Separators and words without a fixation are plain text, never
            // wrapped in restTag (SPEC §2).
            appendEscaped(out, token.text)
            return
        }
        appendOpenTag(out, options.tag, options.className)
        appendEscaped(out, word.fixationText)
        out.append("</").append(options.tag).append('>')
        if (word.restText.isEmpty()) return
        val restTag = options.restTag
        if (restTag == null) {
            appendEscaped(out, word.restText)
        } else {
            appendOpenTag(out, restTag, options.restClassName)
            appendEscaped(out, word.restText)
            out.append("</").append(restTag).append('>')
        }
    }

    private fun consumeTag(raw: String) {
        val parsed = TAG_NAME_RE.find(raw) ?: return // comment, doctype, processing instruction
        val closing = parsed.groupValues[1] == "/"
        val name = parsed.groupValues[2].lowercase()
        val selfClosing = SELF_CLOSING_RE.containsMatchIn(raw)

        val current = skipName
        if (current == null) {
            if (!closing && !selfClosing && name in skip) {
                skipName = name
                skipDepth = 1
            }
            return
        }
        if (name != current || selfClosing) return
        if (!closing) {
            skipDepth += 1
        } else if (--skipDepth <= 0) {
            skipName = null
            skipDepth = 0
        }
    }

    private fun appendOpenTag(out: StringBuilder, name: String, className: String?) {
        out.append('<').append(name)
        if (className != null) {
            out.append(" class=\"")
            appendEscaped(out, className)
            out.append('"')
        }
        out.append('>')
    }

    private companion object {
        /**
         * The characters JavaScript's `\s` matches, so that the tag grammar
         * below is character-for-character the one in the TypeScript core's
         * `html.ts` (Java's own `\s` is ASCII-only and would keep a NBSP or an
         * ideographic space inside a tag name).
         */
        private const val SPACE = "\\t\\n\\u000B\\f\\r \\u00A0\\u1680\\u2000-\\u200A" +
            "\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF"

        /** `/^<\s*(\/?)\s*([a-zA-Z][^\s/>]*)/`: a tag name runs to whitespace, `/` or `>`. */
        private val TAG_NAME_RE = Regex("^<[$SPACE]*(/?)[$SPACE]*([a-zA-Z][^$SPACE/>]*)")

        /** `/\/\s*>$/`: a `/` followed only by whitespace and the final `>`. */
        private val SELF_CLOSING_RE = Regex("/[$SPACE]*>\\z")

        /** Escape the four characters SPEC §4 requires escaping in emitted text. */
        fun appendEscaped(out: StringBuilder, text: String) {
            var flushed = 0
            for (i in text.indices) {
                val replacement = when (text[i]) {
                    '&' -> "&amp;"
                    '<' -> "&lt;"
                    '>' -> "&gt;"
                    '"' -> "&quot;"
                    else -> continue
                }
                out.append(text, flushed, i).append(replacement)
                flushed = i + 1
            }
            out.append(text, flushed, text.length)
        }
    }
}

/**
 * The HTML lexing rules of SPEC §4, mirrored from the TypeScript core's
 * `markup.ts` so the ports can never disagree on what counts as markup:
 *
 * * `<` starts markup only when followed by a letter, `/`, `!` or `?`; the
 *   markup ends at the next `>`, or at `-->` / `]]>` for a `<!--` comment or a
 *   `<![CDATA[` section. An unterminated `<` is text.
 * * `&` starts a character reference only when it forms `&name;`, `&#123;` or
 *   `&#x1F;`; anything else is a bare ampersand and gets escaped.
 */
internal object Markup {

    /**
     * Markup blocks that may contain a bare `>`: comments and CDATA sections.
     * Each entry is `opener to terminator`.
     */
    private val BLOCKS: Array<Pair<String, String>> = arrayOf(
        "<!--" to "-->",
        "<![CDATA[" to "]]>",
    )

    /**
     * Index just past the markup starting at `text[i]` (a `<`), or `-1` when it
     * is text. An unterminated comment or CDATA block degrades to an ordinary
     * `<!...>` declaration, i.e. it ends at the first `>`.
     */
    fun tagEnd(text: String, i: Int): Int {
        if (!isTagStart(text, i)) return -1
        val block = BLOCKS.firstOrNull { text.startsWith(it.first, i) }
        if (block != null) {
            val close = text.indexOf(block.second, i + block.first.length)
            if (close >= 0) return close + block.second.length
        }
        val close = text.indexOf('>', i + 1)
        return if (close < 0) -1 else close + 1
    }

    /** Index just past the character reference starting at `text[i]` (an `&`), or `-1` for a bare `&`. */
    fun entityEnd(text: String, i: Int): Int {
        val n = text.length
        var j = i + 1
        if (j >= n) return -1
        if (text[j] == '#') {
            j += 1
            val hex = j < n && (text[j] == 'x' || text[j] == 'X')
            if (hex) j += 1
            val digitsStart = j
            while (j < n && (if (hex) isHexDigit(text[j]) else text[j] in '0'..'9')) j += 1
            if (j == digitsStart) return -1
        } else {
            if (!isAsciiLetter(text[j])) return -1
            j += 1
            while (j < n && (isAsciiLetter(text[j]) || text[j] in '0'..'9')) j += 1
        }
        return if (j < n && text[j] == ';') j + 1 else -1
    }

    private fun isTagStart(text: String, i: Int): Boolean {
        if (i + 1 >= text.length) return false
        val c = text[i + 1]
        return isAsciiLetter(c) || c == '/' || c == '!' || c == '?'
    }

    private fun isAsciiLetter(c: Char): Boolean = c in 'a'..'z' || c in 'A'..'Z'

    private fun isHexDigit(c: Char): Boolean = c in '0'..'9' || c in 'a'..'f' || c in 'A'..'F'
}
