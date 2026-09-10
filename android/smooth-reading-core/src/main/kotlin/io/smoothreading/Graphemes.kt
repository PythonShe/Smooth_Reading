package io.smoothreading

import java.text.BreakIterator
import java.util.Locale

/**
 * Grapheme-cluster helper (SPEC §3).
 *
 * `BreakIterator.getCharacterInstance()` is ICU-backed on Android
 * (`android.icu.text.BreakIterator`) and rule-based on the JDK; both implement
 * UAX #29 extended grapheme clusters, so combining marks are never split from
 * their base character.
 *
 * One instance is created per tokenize pass and its break iterator is reused
 * for every word, which keeps a 1 MB input free of per-word iterator setup.
 */
internal class Graphemes(private val locale: Locale?) {

    private val iterator: BreakIterator by lazy(LazyThreadSafetyMode.NONE) {
        if (locale == null) BreakIterator.getCharacterInstance() else BreakIterator.getCharacterInstance(locale)
    }

    /** Number of user-perceived characters in [text]. */
    fun count(text: String): Int {
        if (text.isEmpty()) return 0
        val breaks = iterator
        breaks.setText(text)
        var n = 0
        while (breaks.next() != BreakIterator.DONE) n += 1
        return n
    }

    /**
     * Char offset just after the first [clusters] grapheme clusters of [text]
     * (`text.length` when [clusters] exceeds the cluster count).
     */
    fun offsetAfter(text: String, clusters: Int): Int {
        if (clusters <= 0 || text.isEmpty()) return 0
        val breaks = iterator
        breaks.setText(text)
        var end = 0
        repeat(clusters) {
            val next = breaks.next()
            if (next == BreakIterator.DONE) return text.length
            end = next
        }
        return end
    }

    companion object {
        /** One-off count with a fresh iterator. */
        fun count(text: String, locale: Locale? = null): Int = Graphemes(locale).count(text)
    }
}
