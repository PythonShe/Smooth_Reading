package io.smoothreading

/**
 * Stateful HTML renderer (SPEC §4). Everything that must survive across the
 * pieces of one input lives here: the saccade counter and the "am I inside a
 * skipped element?" bookkeeping.
 */
internal class HtmlRenderer(
    private val options: HtmlOptions,
    private val segmenter: WordSegmenter,
) {
    private val counter = SaccadeCounter()
    private val skip: Set<String> =
        options.skipTags.mapTo(HashSet()) { it.lowercase() }.apply { add(options.tag.lowercase()) }

    private var skipName: String? = null
    private var skipDepth = 0

    fun render(text: String): String {
        if (text.isEmpty()) return ""
        if (!options.ignoreHtmlTags) return renderText(text)

        val out = StringBuilder(text.length + text.length / 2)
        var cursor = 0
        for (match in TAG_RE.findAll(text)) {
            val before = text.substring(cursor, match.range.first)
            out.append(if (skipName == null) renderText(before) else before)

            val raw = match.value
            out.append(raw)
            cursor = match.range.last + 1
            consumeTag(raw)
        }
        val tail = text.substring(cursor)
        out.append(if (skipName == null) renderText(tail) else tail)
        return out.toString()
    }

    private fun renderText(text: String): String {
        if (text.isEmpty()) return ""
        val out = StringBuilder(text.length)
        for (token in SmoothReading.tokenize(text, options.smooth, segmenter, counter)) {
            out.append(renderToken(token))
        }
        return out.toString()
    }

    private fun renderToken(token: SmoothToken): String = when (token) {
        is SmoothToken.Separator -> escapeHtml(token.text)
        is SmoothToken.Word ->
            if (token.fixation == 0) {
                escapeHtml(token.text)
            } else {
                buildString {
                    append(openTag(options.tag, options.className))
                    append(escapeHtml(token.fixationText))
                    append("</").append(options.tag).append('>')
                    if (token.restText.isNotEmpty()) {
                        val restTag = options.restTag
                        if (restTag == null) {
                            append(escapeHtml(token.restText))
                        } else {
                            append(openTag(restTag, options.restClassName))
                            append(escapeHtml(token.restText))
                            append("</").append(restTag).append('>')
                        }
                    }
                }
            }
    }

    private fun consumeTag(raw: String) {
        val parsed = TAG_NAME_RE.find(raw) ?: return
        val closing = parsed.groupValues[1] == "/"
        val name = parsed.groupValues[2].lowercase()
        val selfClosing = SELF_CLOSING_RE.containsMatchIn(raw)

        val current = skipName
        if (current != null) {
            if (name != current || selfClosing) return
            if (closing) {
                skipDepth -= 1
                if (skipDepth <= 0) {
                    skipName = null
                    skipDepth = 0
                }
            } else {
                skipDepth += 1
            }
            return
        }

        if (!closing && !selfClosing && name in skip) {
            skipName = name
            skipDepth = 1
        }
    }

    private fun openTag(name: String, className: String?): String =
        if (className == null) "<$name>" else "<$name class=\"${escapeHtml(className)}\">"

    internal companion object {
        private val TAG_RE = Regex("<[^>]*>")
        private val TAG_NAME_RE = Regex("^<\\s*(/?)\\s*([a-zA-Z][^\\s/>]*)")
        private val SELF_CLOSING_RE = Regex("/\\s*>$")

        /** Escape the four characters SPEC §4 requires escaping in emitted text. */
        fun escapeHtml(text: String): String {
            if (text.none { it == '&' || it == '<' || it == '>' || it == '"' }) return text
            val out = StringBuilder(text.length + 8)
            for (ch in text) {
                when (ch) {
                    '&' -> out.append("&amp;")
                    '<' -> out.append("&lt;")
                    '>' -> out.append("&gt;")
                    '"' -> out.append("&quot;")
                    else -> out.append(ch)
                }
            }
            return out.toString()
        }
    }
}
