package io.smoothreading

import java.util.Locale

/**
 * Guided fixation reading (see `docs/SPEC.md`).
 *
 * ```kotlin
 * SmoothReading.toHtml("Smooth reading works.")
 * // <b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.
 * ```
 *
 * The object is stateless and thread-safe; all state (the saccade counter and
 * the grapheme break iterator) lives for the duration of a single call.
 */
public object SmoothReading {

    /**
     * How many grapheme clusters of [word] to emphasise (SPEC §2).
     *
     * Honours [SmoothOptions.fixationLength] when one is set (its result is
     * clamped to `0..graphemes`), otherwise runs the default ratio algorithm.
     * Exposed so custom overrides can delegate to it for the cases they do not
     * care about.
     *
     * @param word the word exactly as tokenized
     * @param graphemes number of user-perceived characters in [word]; counted
     *   with a break iterator when omitted
     * @param options fixation options
     */
    @JvmStatic
    @JvmOverloads
    public fun fixationLength(
        word: String,
        graphemes: Int = Graphemes.count(word, null),
        options: SmoothOptions = SmoothOptions.DEFAULTS,
    ): Int {
        val override = options.fixationLength ?: return Fixation.default(word, graphemes, options)
        return override(word, graphemes, options).coerceIn(0, graphemes)
    }

    /**
     * Split [text] into words and separators and compute each word's split
     * (SPEC §3, §4). Concatenating `token.text` gives [text] back.
     *
     * @param text the text to tokenize
     * @param options fixation options
     * @param segmenter word breaker; [SpecWordSegmenter] by default
     */
    @JvmStatic
    @JvmOverloads
    public fun tokenize(
        text: String,
        options: SmoothOptions = SmoothOptions.DEFAULTS,
        segmenter: WordSegmenter = SpecWordSegmenter,
    ): List<SmoothToken> = tokenize(text, options, segmenter, TokenizeState(options.locale))

    /**
     * Render [text] as HTML, emphasising the fixation prefix of every word
     * (SPEC §4).
     *
     * `<`, `>`, `&` and `"` are escaped in emitted text. With
     * [HtmlOptions.ignoreHtmlTags] (the default) existing tags and character
     * references are passed through verbatim and text inside
     * [HtmlOptions.skipTags] — and inside the emphasis tags themselves — is
     * left untouched.
     *
     * @param text plain text, or HTML when [HtmlOptions.ignoreHtmlTags] is set
     * @param options HTML and fixation options
     * @param segmenter word breaker; [SpecWordSegmenter] by default
     */
    @JvmStatic
    @JvmOverloads
    public fun toHtml(
        text: String,
        options: HtmlOptions = HtmlOptions.DEFAULTS,
        segmenter: WordSegmenter = SpecWordSegmenter,
    ): String = HtmlRenderer(options, segmenter).render(text)

    /** Convenience overload: default HTML settings, custom fixation options. */
    @JvmStatic
    public fun toHtml(text: String, options: SmoothOptions): String =
        toHtml(text, HtmlOptions(options))

    /** [tokenize] with externally owned pass state, so `toHtml` can share it across pieces. */
    internal fun tokenize(
        text: String,
        options: SmoothOptions,
        segmenter: WordSegmenter,
        state: TokenizeState,
    ): List<SmoothToken> {
        if (text.isEmpty()) return emptyList()
        val segments = segmenter.segment(text)
        val tokens = ArrayList<SmoothToken>(segments.size)
        for (segment in segments) {
            tokens.add(
                if (segment.isWord) {
                    wordToken(segment.text, options, state)
                } else {
                    SmoothToken.Separator(segment.text)
                },
            )
        }
        return tokens
    }

    private fun wordToken(word: String, options: SmoothOptions, state: TokenizeState): SmoothToken.Word {
        // Every word token consumes a saccade index, including numbers and
        // words too short to be emphasised (SPEC §4).
        if (!state.nextWordIsOnSaccade(options.saccade)) return SmoothToken.Word(word, 0, "", word)

        val graphemes = state.graphemes.count(word)
        val fixation = fixationLength(word, graphemes, options)
        if (fixation <= 0) return SmoothToken.Word(word, 0, "", word)

        val split = state.graphemes.offsetAfter(word, fixation)
        return SmoothToken.Word(word, fixation, word.substring(0, split), word.substring(split))
    }
}

/**
 * State shared across the pieces of one tokenize/render pass: the saccade
 * counter (which must not restart at an HTML tag) and the grapheme break
 * iterator (reused for every word).
 */
internal class TokenizeState(locale: Locale?) {
    val graphemes: Graphemes = Graphemes(locale)
    private var wordIndex = 0

    /** Advance the counter; `true` when the word just counted is on a saccade boundary. */
    fun nextWordIsOnSaccade(saccade: Int): Boolean {
        val onSaccade = wordIndex % saccade == 0
        wordIndex += 1
        return onSaccade
    }
}
