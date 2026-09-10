package io.smoothreading.android

import android.icu.text.BreakIterator
import io.smoothreading.RawSegment
import io.smoothreading.WordSegmenter
import java.util.Locale

/**
 * Tokenizer backed by `android.icu.text.BreakIterator` (SPEC §3).
 *
 * ICU implements UAX #29 word breaking with dictionary support for Chinese,
 * Japanese, Khmer, Lao and Thai, so this is the Android equivalent of
 * `Intl.Segmenter` in the TypeScript core: apostrophes join, hyphens split, and
 * the `fixtures/segmenter` cases apply in addition to `fixtures/common`.
 *
 * It is the default for [annotatedString] and [spanned]. Pass
 * `io.smoothreading.SpecWordSegmenter` instead when you need output that is
 * byte-identical with the pure-regex ports (Python, and JS without
 * `Intl.Segmenter`) for inputs such as `3.14` where ICU and the regex differ.
 *
 * @param locale the locale handed to ICU; `null` = device default
 */
public class IcuWordSegmenter(private val locale: Locale? = null) : WordSegmenter {

    override fun segment(text: String): List<RawSegment> {
        if (text.isEmpty()) return emptyList()
        val iterator = if (locale == null) BreakIterator.getWordInstance() else BreakIterator.getWordInstance(locale)
        iterator.setText(text)

        val out = ArrayList<RawSegment>()
        var separatorStart = 0
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            // Statuses below WORD_NONE_LIMIT cover whitespace and punctuation;
            // everything above (NUMBER, LETTER, KANA, IDEO) is word-like, which
            // is exactly `Intl.Segmenter`'s `isWordLike`.
            if (iterator.ruleStatus >= BreakIterator.WORD_NONE_LIMIT) {
                if (separatorStart < start) out.add(RawSegment(text.substring(separatorStart, start), isWord = false))
                out.add(RawSegment(text.substring(start, end), isWord = true))
                separatorStart = end
            }
            start = end
            end = iterator.next()
        }
        if (separatorStart < text.length) out.add(RawSegment(text.substring(separatorStart), isWord = false))
        return out
    }
}
