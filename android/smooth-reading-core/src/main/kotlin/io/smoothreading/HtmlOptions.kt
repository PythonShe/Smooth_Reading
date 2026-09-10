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
 * @property tag element wrapped around the fixation prefix. Default `"b"`.
 * @property className class attribute for [tag]. `null` = no attribute.
 * @property restTag optional element wrapped around the remainder of the word.
 * @property restClassName class attribute for [restTag].
 * @property ignoreHtmlTags when `true` (default) anything that looks like a tag
 *   is passed through verbatim and never escaped or tokenized.
 * @property skipTags elements whose text content is never rewritten. The
 *   emphasis [tag] itself is always skipped as well, so already-emphasised
 *   markup is never wrapped twice (SPEC §4).
 */
public data class HtmlOptions(
    val smooth: SmoothOptions = SmoothOptions(),
    val tag: String = DEFAULT_TAG,
    val className: String? = null,
    val restTag: String? = null,
    val restClassName: String? = null,
    val ignoreHtmlTags: Boolean = true,
    val skipTags: List<String> = DEFAULT_SKIP_TAGS,
) {
    public companion object {
        /** Default element name for the fixation prefix. */
        public const val DEFAULT_TAG: String = "b"

        /** Elements whose text content is never rewritten (SPEC §4). */
        @JvmField
        public val DEFAULT_SKIP_TAGS: List<String> =
            listOf("code", "pre", "script", "style", "kbd", "samp", "textarea")
    }
}
