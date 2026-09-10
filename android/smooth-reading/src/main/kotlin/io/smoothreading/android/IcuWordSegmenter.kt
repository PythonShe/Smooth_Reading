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
 */
public class IcuWordSegmenter(private val locale: Locale? = null) : WordSegmenter {

    override fun segment(text: String): List<RawSegment> {
        if (text.isEmpty()) return emptyList()
        val iterator = if (locale == null) {
            BreakIterator.getWordInstance()
        } else {
            BreakIterator.getWordInstance(locale)
        }
        iterator.setText(text)

        val out = ArrayList<RawSegment>()
        var start = iterator.first()
        var end = iterator.next()
        var ruleStatus = iterator.ruleStatus
        while (end != BreakIterator.DONE) {
            val piece = text.substring(start, end)
            // Statuses below WORD_NONE_LIMIT cover whitespace and punctuation;
            // everything above (NUMBER, LETTER, KANA, IDEO) is word-like, which
            // is exactly `Intl.Segmenter`'s `isWordLike`.
            val isWord = ruleStatus >= BreakIterator.WORD_NONE_LIMIT
            if (isWord) {
                out.add(RawSegment(piece, isWord = true))
            } else {
                val last = out.lastOrNull()
                if (last != null && !last.isWord) {
                    out[out.size - 1] = RawSegment(last.text + piece, isWord = false)
                } else {
                    out.add(RawSegment(piece, isWord = false))
                }
            }
            start = end
            end = iterator.next()
            ruleStatus = iterator.ruleStatus
        }
        return out
    }
}
