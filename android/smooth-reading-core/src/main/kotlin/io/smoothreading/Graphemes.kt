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
 * SPEC §3 requires **Unicode 15.1** grapheme rules, which the JDK's own
 * iterator does not yet provide: JDK 21 (the toolchain this library is built
 * and tested with) predates GB9c, so it splits the Devanagari conjunct `क्ष`
 * after the virama. Rather than tying correctness to the JDK a consumer
 * happens to run on, this class applies a small post-pass over the iterator's
 * boundaries and merges neighbouring clusters that the spec's approximation
 * keeps together (the same rules `python/smooth_reading/graphemes.py`
 * implements from scratch):
 *
 * * Hangul jamo compose (GB6–GB8): `L* (V+ | LV | LVT) T*` is one syllable;
 * * Indic conjuncts link (GB9c): a consonant, a virama and the next consonant
 *   of Devanagari, Bengali, Gujarati, Oriya, Telugu or Malayalam — the Unicode
 *   15.1 `Indic_Conjunct_Break` scripts — stay in one cluster, with any
 *   combining marks or ZWJ between them.
 *
 * On engines that already implement those rules (ICU ≥ 74 on Android, newer
 * JDKs) the post-pass never finds anything to merge, so the results are the
 * same everywhere. Linking for the scripts Unicode 17 added (Khmer, Myanmar,
 * Tai Tham, Balinese, Sundanese) is deliberately *not* applied, matching the
 * other ports.
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
        var n = 0
        forEachClusterEnd(text) { n += 1 }
        return n
    }

    /**
     * Char offset just after the first [clusters] grapheme clusters of [text]
     * (`text.length` when [clusters] exceeds the cluster count).
     */
    fun offsetAfter(text: String, clusters: Int): Int {
        if (clusters <= 0) return 0
        var remaining = clusters
        forEachClusterEnd(text) { end ->
            remaining -= 1
            if (remaining == 0) return end
        }
        return text.length
    }

    /**
     * Calls [action] with the end offset of every grapheme cluster of [text],
     * in order. Boundaries come from the break iterator; a boundary is dropped
     * when [joins] says the clusters on both sides belong together.
     */
    private inline fun forEachClusterEnd(text: String, action: (end: Int) -> Unit) {
        if (text.isEmpty()) return
        val breaks = iterator
        breaks.setText(text)
        var clusterStart = 0
        var end = breaks.next()
        while (end != BreakIterator.DONE) {
            val next = breaks.next()
            if (next == BreakIterator.DONE || !joins(text, clusterStart, end)) {
                action(end)
                clusterStart = end
            }
            end = next
        }
    }

    companion object {

        /** One-off count with a fresh iterator. */
        fun count(text: String, locale: Locale? = null): Int = Graphemes(locale).count(text)

        /**
         * Whether the iterator's boundary at [boundary] should be dropped, so
         * that the cluster starting at [clusterStart] absorbs the next one.
         */
        private fun joins(text: String, clusterStart: Int, boundary: Int): Boolean {
            val before = text.codePointBefore(boundary)
            val after = text.codePointAt(boundary)
            if (hangulJoins(jamoClass(before), jamoClass(after))) return true
            return isIndicConsonant(after) && endsWithLinker(text, clusterStart, boundary)
        }

        // ---- Hangul (GB6–GB8) -------------------------------------------------

        private const val JAMO_NONE = 0
        private const val JAMO_L = 1
        private const val JAMO_V = 2
        private const val JAMO_T = 3
        private const val JAMO_LV = 4
        private const val JAMO_LVT = 5

        /** `Hangul_Syllable_Type`; LV syllables are every 28th code point from U+AC00. */
        private fun jamoClass(cp: Int): Int = when (cp) {
            in 0xAC00..0xD7A3 -> if ((cp - 0xAC00) % 28 == 0) JAMO_LV else JAMO_LVT
            in 0x1100..0x115F, in 0xA960..0xA97C -> JAMO_L
            in 0x1160..0x11A7, in 0xD7B0..0xD7C6 -> JAMO_V
            in 0x11A8..0x11FF, in 0xD7CB..0xD7FB -> JAMO_T
            else -> JAMO_NONE
        }

        private fun hangulJoins(previous: Int, following: Int): Boolean = when (previous) {
            JAMO_NONE -> false
            JAMO_L -> following == JAMO_L || following == JAMO_V || following == JAMO_LV || following == JAMO_LVT
            JAMO_LV, JAMO_V -> following == JAMO_V || following == JAMO_T
            else -> following == JAMO_T // (LVT | T) × T
        }

        // ---- Indic conjuncts (GB9c, Unicode 15.1) --------------------------------

        /** `Indic_Conjunct_Break=Linker`: the viramas of the six scripts. */
        private fun isIndicLinker(cp: Int): Boolean = when (cp) {
            0x094D, 0x09CD, 0x0ACD, 0x0B4D, 0x0C4D, 0x0D4D -> true
            else -> false
        }

        /** `Indic_Conjunct_Break=Consonant` (same ranges as the Python port). */
        private fun isIndicConsonant(cp: Int): Boolean = when (cp) {
            in 0x0915..0x0939, in 0x0958..0x095F, in 0x0978..0x097F, // Devanagari
            in 0x0995..0x09A8, in 0x09AA..0x09B0, 0x09B2, in 0x09B6..0x09B9, // Bengali
            in 0x09DC..0x09DD, 0x09DF, in 0x09F0..0x09F1,
            in 0x0A95..0x0AA8, in 0x0AAA..0x0AB0, in 0x0AB2..0x0AB3, in 0x0AB5..0x0AB9, 0x0AF9, // Gujarati
            in 0x0B15..0x0B28, in 0x0B2A..0x0B30, in 0x0B32..0x0B33, in 0x0B35..0x0B39, // Oriya
            in 0x0B5C..0x0B5D, 0x0B5F, 0x0B71,
            in 0x0C15..0x0C28, in 0x0C2A..0x0C39, in 0x0C58..0x0C5A, // Telugu
            in 0x0D15..0x0D3A, // Malayalam
            -> true

            else -> false
        }

        /** `Indic_Conjunct_Break=Extend`: combining marks and ZWJ. */
        private fun isIndicExtend(cp: Int): Boolean = when (Character.getType(cp).toByte()) {
            Character.NON_SPACING_MARK, Character.ENCLOSING_MARK, Character.COMBINING_SPACING_MARK -> true
            else -> cp == 0x200D
        }

        /**
         * GB9c's left-hand side: scanning back from [end] over
         * `[Extend Linker]*`, at least one linker was seen and a consonant
         * precedes them, all within `[from, end)`.
         */
        private fun endsWithLinker(text: String, from: Int, end: Int): Boolean {
            var i = end
            var linked = false
            while (i > from) {
                val cp = text.codePointBefore(i)
                when {
                    isIndicLinker(cp) -> linked = true
                    isIndicExtend(cp) -> Unit
                    else -> return linked && isIndicConsonant(cp)
                }
                i -= Character.charCount(cp)
            }
            return false
        }
    }
}
