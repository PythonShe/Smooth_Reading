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
 * The object is stateless and thread-safe; all state (the saccade counter)
 * lives for the duration of a single call.
 */
public object SmoothReading {

    /**
     * The tokenizer used when none is given.
     *
     * [SpecWordSegmenter] on every runtime: it is the only implementation that
     * agrees with the other ports on every `fixtures/common` case. The Android
     * artifact opts into the ICU break iterator explicitly — see
     * [BreakIteratorWordSegmenter].
     */
    @JvmStatic
    @JvmOverloads
    @Suppress("UNUSED_PARAMETER")
    public fun defaultSegmenter(locale: Locale? = null): WordSegmenter = SpecWordSegmenter

    /**
     * How many grapheme clusters of [word] to emphasise (SPEC §2).
     *
     * Honours [SmoothOptions.fixationLength] when one is set, otherwise runs
     * the default ratio algorithm. Exposed so custom overrides can delegate to
     * it for the cases they do not care about.
     */
    @JvmStatic
    @JvmOverloads
    public fun fixationLength(
        word: String,
        graphemes: Int = Graphemes.count(word),
        options: SmoothOptions = SmoothOptions.DEFAULTS,
    ): Int {
        val override = options.fixationLength ?: return Fixation.default(word, graphemes, options)
        return override(word, graphemes, options).coerceIn(0, graphemes)
    }

    /** Split [text] into words and separators and compute each word's split (SPEC §3, §4). */
    @JvmStatic
    @JvmOverloads
    public fun tokenize(
        text: String,
        options: SmoothOptions = SmoothOptions.DEFAULTS,
        segmenter: WordSegmenter = defaultSegmenter(options.locale),
    ): List<SmoothToken> = tokenize(text, options, segmenter, SaccadeCounter())

    /**
     * Render [text] as HTML, emphasising the fixation prefix of every word
     * (SPEC §4).
     *
     * `<`, `>`, `&` and `"` are escaped in emitted text; with
     * [HtmlOptions.ignoreHtmlTags] existing markup is passed through verbatim.
     */
    @JvmStatic
    @JvmOverloads
    public fun toHtml(
        text: String,
        options: HtmlOptions = HtmlOptions(),
        segmenter: WordSegmenter = defaultSegmenter(options.smooth.locale),
    ): String = HtmlRenderer(options, segmenter).render(text)

    /** Convenience overload: default HTML settings, custom fixation options. */
    @JvmStatic
    public fun toHtml(text: String, options: SmoothOptions): String =
        toHtml(text, HtmlOptions(options))

    internal fun tokenize(
        text: String,
        options: SmoothOptions,
        segmenter: WordSegmenter,
        counter: SaccadeCounter,
    ): List<SmoothToken> {
        if (text.isEmpty()) return emptyList()
        return segmenter.segment(text).map { segment ->
            if (segment.isWord) {
                wordToken(segment.text, options, counter)
            } else {
                SmoothToken.Separator(segment.text)
            }
        }
    }

    private fun wordToken(
        word: String,
        options: SmoothOptions,
        counter: SaccadeCounter,
    ): SmoothToken.Word {
        // Saccade counts *every* word token, including numbers and words too
        // short to be emphasised (SPEC §4).
        val onSaccade = counter.next(options.saccade)
        if (!onSaccade) return SmoothToken.Word(word, 0, "", word)

        val graphemes = Graphemes.split(word, options.locale)
        val fixation = fixationLength(word, graphemes.size, options)
        if (fixation <= 0) return SmoothToken.Word(word, 0, "", word)

        val prefix = graphemes.subList(0, fixation).joinToString("")
        val rest = graphemes.subList(fixation, graphemes.size).joinToString("")
        return SmoothToken.Word(word, fixation, prefix, rest)
    }
}

/** Saccade bookkeeping shared across one rendering pass. */
internal class SaccadeCounter {
    private var wordIndex = 0

    /** `true` when the next word is on a saccade boundary. */
    fun next(saccade: Int): Boolean {
        val onSaccade = wordIndex % saccade == 0
        wordIndex += 1
        return onSaccade
    }
}
