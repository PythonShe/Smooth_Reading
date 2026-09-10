package io.smoothreading

import java.text.BreakIterator
import java.util.Locale

/** A slice of the input plus whether it is word-like. */
public data class RawSegment(val text: String, val isWord: Boolean)

/**
 * Splits text into word and separator segments (SPEC §3).
 *
 * Two implementations ship with the core:
 *
 * * [SpecWordSegmenter] — the spec's Unicode regular expression
 *   `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*` plus the scriptio-continua
 *   rule. This is the default on the JVM and the only tokenizer that is
 *   guaranteed to agree with the other ports on every `fixtures/common` case.
 * * [BreakIteratorWordSegmenter] — `java.text.BreakIterator`. On Android that
 *   is `android.icu.text.BreakIterator`, i.e. real UAX #29 word breaking with
 *   dictionary support for Chinese, Japanese and Thai; it also satisfies
 *   `fixtures/segmenter`.
 *
 * ### Why the JVM default is not `BreakIterator`
 *
 * The JDK's `BreakIterator.getWordInstance()` is the legacy rule-based
 * iterator, not ICU, and it disagrees with the spec (verified locally on
 * JDK 26):
 *
 * ```
 * don't       -> [don't]                 (spec: one word — agrees)
 * don’t       -> [don][’][t]             (spec: one word — DISAGREES)
 * well-known  -> [well-known]            (spec: two words — DISAGREES)
 * ```
 *
 * Since hyphen splitting and U+2019 joining are both spec rules exercised by
 * the shared fixtures, plain-JVM consumers get [SpecWordSegmenter] by default
 * and `BreakIterator` is still used for grapheme counting (see [Graphemes]),
 * where the JDK implementation is UAX #29 conformant.
 */
public fun interface WordSegmenter {
    /** Split [text]; consecutive non-word pieces are merged into one separator. */
    public fun segment(text: String): List<RawSegment>
}

/**
 * The tokenizer of SPEC §3's fallback: maximal runs of `\p{L}\p{N}\p{M}`
 * joined by `'` or `’`, with runs of scriptio-continua scripts (Han, Kana,
 * Hangul, Thai) forming words of their own. Hand-written rather than
 * regex-driven so that the CJK rule and the regex share one pass.
 */
public object SpecWordSegmenter : WordSegmenter {

    private val APOSTROPHES = charArrayOf('\'', '’')

    override fun segment(text: String): List<RawSegment> {
        if (text.isEmpty()) return emptyList()
        val out = ArrayList<RawSegment>()
        val separator = StringBuilder()

        fun flushSeparator() {
            if (separator.isNotEmpty()) {
                out.add(RawSegment(separator.toString(), isWord = false))
                separator.setLength(0)
            }
        }

        var i = 0
        while (i < text.length) {
            val cp = text.codePointAt(i)
            val width = Character.charCount(cp)
            when {
                isContinuous(cp) -> {
                    val start = i
                    while (i < text.length) {
                        val next = text.codePointAt(i)
                        if (!isContinuous(next)) break
                        i += Character.charCount(next)
                    }
                    flushSeparator()
                    out.add(RawSegment(text.substring(start, i), isWord = true))
                }

                isWordChar(cp) -> {
                    val start = i
                    i = scanWord(text, i)
                    flushSeparator()
                    out.add(RawSegment(text.substring(start, i), isWord = true))
                }

                else -> {
                    separator.append(text, i, i + width)
                    i += width
                }
            }
        }
        flushSeparator()
        return out
    }

    /** Consume `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*` from [from]. */
    private fun scanWord(text: String, from: Int): Int {
        var i = from
        while (i < text.length) {
            val cp = text.codePointAt(i)
            if (isWordChar(cp) && !isContinuous(cp)) {
                i += Character.charCount(cp)
                continue
            }
            // An apostrophe only stays inside the word when a word character
            // follows it.
            if (Character.charCount(cp) == 1 && cp.toChar() in APOSTROPHES) {
                val next = i + 1
                if (next < text.length) {
                    val after = text.codePointAt(next)
                    if (isWordChar(after) && !isContinuous(after)) {
                        i = next
                        continue
                    }
                }
            }
            break
        }
        return i
    }

    private fun isWordChar(cp: Int): Boolean = when (Character.getType(cp).toByte()) {
        Character.UPPERCASE_LETTER,
        Character.LOWERCASE_LETTER,
        Character.TITLECASE_LETTER,
        Character.MODIFIER_LETTER,
        Character.OTHER_LETTER,
        Character.DECIMAL_DIGIT_NUMBER,
        Character.LETTER_NUMBER,
        Character.OTHER_NUMBER,
        Character.NON_SPACING_MARK,
        Character.ENCLOSING_MARK,
        Character.COMBINING_SPACING_MARK,
        -> true

        else -> false
    }

    /** Scripts written without spaces; a run of these is one word (SPEC §3). */
    private fun isContinuous(cp: Int): Boolean = when (Character.UnicodeScript.of(cp)) {
        Character.UnicodeScript.HAN,
        Character.UnicodeScript.HIRAGANA,
        Character.UnicodeScript.KATAKANA,
        Character.UnicodeScript.HANGUL,
        Character.UnicodeScript.THAI,
        -> true

        else -> false
    }
}

/**
 * `java.text.BreakIterator`-backed tokenizer — ICU on Android
 * (`android.icu.text.BreakIterator`), the JDK's rule-based iterator on the JVM.
 * A segment counts as a word when it contains at least one letter, digit or
 * mark, which is the equivalent of `Intl.Segmenter`'s `isWordLike`.
 */
public class BreakIteratorWordSegmenter(private val locale: Locale? = null) : WordSegmenter {

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
        while (end != BreakIterator.DONE) {
            val piece = text.substring(start, end)
            if (isWordLike(piece)) {
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
        }
        return out
    }

    private fun isWordLike(piece: String): Boolean =
        piece.any { Character.isLetterOrDigit(it) || Character.getType(it) == Character.NON_SPACING_MARK.toInt() }
}
