package io.smoothreading

import java.text.BreakIterator
import java.util.Locale

/**
 * Grapheme-cluster helpers (SPEC §3).
 *
 * `BreakIterator.getCharacterInstance()` is ICU-backed on Android
 * (`android.icu.text.BreakIterator`) and rule-based on the JDK; both implement
 * UAX #29 extended grapheme clusters, so combining marks are never split from
 * their base character.
 */
public object Graphemes {

    /** Split [text] into grapheme clusters. */
    @JvmStatic
    @JvmOverloads
    public fun split(text: String, locale: Locale? = null): List<String> {
        if (text.isEmpty()) return emptyList()
        val iterator = characterInstance(locale)
        iterator.setText(text)
        val out = ArrayList<String>(text.length)
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            out.add(text.substring(start, end))
            start = end
            end = iterator.next()
        }
        return out
    }

    /** Number of user-perceived characters in [text]. */
    @JvmStatic
    @JvmOverloads
    public fun count(text: String, locale: Locale? = null): Int = split(text, locale).size

    private fun characterInstance(locale: Locale?): BreakIterator =
        if (locale == null) {
            BreakIterator.getCharacterInstance()
        } else {
            BreakIterator.getCharacterInstance(locale)
        }
}
