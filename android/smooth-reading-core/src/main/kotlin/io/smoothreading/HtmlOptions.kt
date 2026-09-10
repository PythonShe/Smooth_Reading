package io.smoothreading

/**
 * Options for [SmoothReading.toHtml] (SPEC §4).
 *
 * Kotlin data classes cannot extend one another, so the fixation options are
 * held by composition in [smooth] instead of being inherited:
 *
 * ```kotlin
 * SmoothReading.toHtml(text, HtmlOptions(SmoothOptions(fixation = 4), tag = "span", className = "sr-fixation"))
 * ```
 *
 * @property smooth the fixation options.
 * @property tag element wrapped around the fixation prefix. Default `"b"`.
 * @property className class attribute for [tag]. `null` = no attribute.
 * @property restTag optional element wrapped around the remainder of the word.
 *   Words without a fixation are emitted as plain text, never wrapped.
 * @property restClassName class attribute for [restTag].
 * @property ignoreHtmlTags when `true` (default) existing tags and character
 *   references are passed through verbatim and act as word boundaries; only a
 *   bare `&` and a `<` that does not start markup are escaped. When `false` the
 *   input is plain text and every `<`, `>`, `&`, `"` is escaped.
 * @property skipTags elements whose text content is never rewritten
 *   (case-insensitive). With [ignoreHtmlTags], [tag] and [restTag] are
 *   implicitly skipped as well, so already-emphasised markup is never wrapped
 *   twice (SPEC §4).
 */
public data class HtmlOptions(
    val smooth: SmoothOptions = SmoothOptions.DEFAULTS,
    val tag: String = DEFAULT_TAG,
    val className: String? = null,
    val restTag: String? = null,
    val restClassName: String? = null,
    val ignoreHtmlTags: Boolean = true,
    val skipTags: List<String> = DEFAULT_SKIP_TAGS,
) {
    init {
        require(isElementName(tag)) { "tag must be an element name, was \"$tag\"" }
        require(restTag == null || isElementName(restTag)) { "restTag must be an element name, was \"$restTag\"" }
    }

    public companion object {
        /** Default element name for the fixation prefix. */
        public const val DEFAULT_TAG: String = "b"

        /** Elements whose text content is never rewritten (SPEC §4). */
        @JvmField
        public val DEFAULT_SKIP_TAGS: List<String> =
            listOf("code", "pre", "script", "style", "kbd", "samp", "textarea")

        /** The defaults of SPEC §4. */
        @JvmField
        public val DEFAULTS: HtmlOptions = HtmlOptions()

        /** An ASCII letter followed by anything that cannot end or break a tag. */
        private fun isElementName(name: String): Boolean =
            name.isNotEmpty() &&
                (name[0] in 'a'..'z' || name[0] in 'A'..'Z') &&
                name.none { it.isWhitespace() || it == '<' || it == '>' || it == '/' || it == '"' }
    }
}
