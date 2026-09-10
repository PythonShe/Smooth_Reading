package io.smoothreading

/**
 * A slice of the input plus whether it is word-like.
 *
 * @property text the slice, exactly as it appears in the input
 * @property isWord `true` for a word, `false` for whitespace, punctuation or
 *   any other separator
 */
public data class RawSegment(val text: String, val isWord: Boolean)

/**
 * Splits text into word and separator segments (SPEC §3).
 *
 * Contract: concatenating the `text` of every segment must give the input
 * back unchanged, and consecutive non-word pieces are merged into a single
 * separator. The adapters rely on the round trip to map tokens back to char
 * offsets of the original string.
 *
 * Two implementations ship with the project:
 *
 * * [SpecWordSegmenter] — the spec's Unicode regular expression
 *   `[\p{L}\p{N}][\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*` plus the
 *   no-space-script run rule. It is the default and the only tokenizer guaranteed to agree with
 *   the other ports on every `fixtures/common` case.
 * * `io.smoothreading.android.IcuWordSegmenter` (Android artifact) —
 *   `android.icu.text.BreakIterator`, i.e. real UAX #29 word breaking with
 *   dictionary support for Chinese, Japanese and Thai; it also satisfies
 *   `fixtures/segmenter`.
 *
 * The JDK's own `java.text.BreakIterator.getWordInstance()` is deliberately
 * not offered: it is the legacy rule-based iterator, not ICU, and it keeps
 * `well-known` as one word and splits `don’t` into three, both of which
 * contradict SPEC §3.
 */
public fun interface WordSegmenter {
    /** Split [text] into words and separators; see the class contract. */
    public fun segment(text: String): List<RawSegment>
}

/**
 * The tokenizer of SPEC §3's fallback: a letter or digit followed by a maximal
 * run of `\p{L}\p{N}\p{M}`, joined by `'` or `’`, with runs of no-space-script
 * characters (Han, Kana, Hangul, Thai, Lao, Myanmar, Khmer) forming words of
 * their own — one word per continuous run, split from the letters and digits of
 * any other script (`iPhone手机` is two words, so is `abcก`). A combining mark
 * that follows a run character stays attached to the run (`我́` is one word).
 * A word never *starts* with a combining mark: a mark that follows a
 * separator — the variation selector of `❤️`, say — stays in the separator,
 * as ICU's UAX #29 WB4 keeps it with the preceding symbol. Hand-written
 * rather than regex-driven so that the run rule and the regex share one
 * linear pass.
 */
public object SpecWordSegmenter : WordSegmenter {

    override fun segment(text: String): List<RawSegment> {
        if (text.isEmpty()) return emptyList()
        val out = ArrayList<RawSegment>()
        var separatorStart = 0
        var i = 0
        while (i < text.length) {
            val cp = text.codePointAt(i)
            val end = when {
                !isWordStart(cp) -> {
                    i += Character.charCount(cp)
                    continue
                }

                isRunChar(cp) -> scanRun(text, i)
                else -> scanWord(text, i)
            }
            if (separatorStart < i) out.add(RawSegment(text.substring(separatorStart, i), isWord = false))
            out.add(RawSegment(text.substring(i, end), isWord = true))
            i = end
            separatorStart = end
        }
        if (separatorStart < text.length) out.add(RawSegment(text.substring(separatorStart), isWord = false))
        return out
    }

    /**
     * Consume a run of no-space-script code points starting at [from].
     * Combining marks that follow a run character belong to the run rather
     * than to the separator after it.
     */
    private fun scanRun(text: String, from: Int): Int {
        var i = from
        while (i < text.length) {
            val cp = text.codePointAt(i)
            if (!isRunChar(cp) && !isMark(cp)) break
            i += Character.charCount(cp)
        }
        return i
    }

    /**
     * Consume `[\p{L}\p{N}\p{M}]*(?:['’][\p{L}\p{N}\p{M}]+)*` from [from];
     * the caller has checked that [from] is a letter or digit.
     */
    private fun scanWord(text: String, from: Int): Int {
        var i = from
        while (i < text.length) {
            val cp = text.codePointAt(i)
            if (isWordChar(cp) && !isRunChar(cp)) {
                i += Character.charCount(cp)
                continue
            }
            // An apostrophe only stays inside the word when a word character
            // that is not itself a run character follows it: a run character
            // starts a word of its own.
            if ((cp == '\''.code || cp == '’'.code) && i + 1 < text.length) {
                val after = text.codePointAt(i + 1)
                if (isWordChar(after) && !isRunChar(after)) {
                    i += 1
                    continue
                }
            }
            break
        }
        return i
    }

    /** `\p{L}` or `\p{N}`: what a word may begin with. */
    private fun isWordStart(cp: Int): Boolean = when (Character.getType(cp).toByte()) {
        Character.UPPERCASE_LETTER,
        Character.LOWERCASE_LETTER,
        Character.TITLECASE_LETTER,
        Character.MODIFIER_LETTER,
        Character.OTHER_LETTER,
        Character.DECIMAL_DIGIT_NUMBER,
        Character.LETTER_NUMBER,
        Character.OTHER_NUMBER,
        -> true

        else -> false
    }

    /** `\p{L}`, `\p{N}` or `\p{M}`: what may continue a word. */
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

    /** `\p{M}`: a combining mark. */
    private fun isMark(cp: Int): Boolean = when (Character.getType(cp).toByte()) {
        Character.NON_SPACING_MARK,
        Character.ENCLOSING_MARK,
        Character.COMBINING_SPACING_MARK,
        -> true

        else -> false
    }

    /**
     * A character of a script written without spaces; a continuous run of these
     * is one word (SPEC §3), split from the letters and digits around it.
     *
     * The table is the one every regex-fallback port shares (the Python port's
     * `_CJK_RANGES`); a character only counts when it is a letter, number or
     * mark, so the Katakana middle dot `・` (punctuation) stays a separator.
     */
    private fun isRunChar(cp: Int): Boolean = isWordChar(cp) && inRunTable(cp)

    /** Binary search over [RUN_RANGES]'s inclusive `[low, high]` pairs. */
    private fun inRunTable(cp: Int): Boolean {
        var low = 0
        var high = RUN_RANGES.size / 2 - 1
        while (low <= high) {
            val mid = (low + high) ushr 1
            when {
                cp < RUN_RANGES[mid * 2] -> high = mid - 1
                cp > RUN_RANGES[mid * 2 + 1] -> low = mid + 1
                else -> return true
            }
        }
        return false
    }

    /** Inclusive `low, high` code-point pairs, ascending; see [isRunChar]. */
    private val RUN_RANGES = intArrayOf(
        0x0E00, 0x0E7F, // Thai
        0x0E80, 0x0EFF, // Lao
        0x1000, 0x109F, // Myanmar
        0x1100, 0x11FF, // Hangul Jamo
        0x1780, 0x17FF, // Khmer
        0x3005, 0x3007, // ideographic iteration mark, ideographic zero
        0x3041, 0x30FF, // Hiragana, Katakana
        0x3130, 0x318F, // Hangul Compatibility Jamo
        0x31F0, 0x31FF, // Katakana Phonetic Extensions
        0x3400, 0x4DBF, // CJK Extension A
        0x4E00, 0x9FFF, // CJK Unified Ideographs
        0xA960, 0xA97F, // Hangul Jamo Extended-A
        0xA9E0, 0xA9FF, // Myanmar Extended-B
        0xAA60, 0xAA7F, // Myanmar Extended-A
        0xAC00, 0xD7A3, // Hangul Syllables
        0xD7B0, 0xD7FF, // Hangul Jamo Extended-B
        0xF900, 0xFAFF, // CJK Compatibility Ideographs
        0xFF66, 0xFF9D, // halfwidth Katakana
        0xFFA0, 0xFFDC, // halfwidth Hangul
        0x20000, 0x2EBEF, // CJK Extensions B-F
        0x2F800, 0x2FA1F, // CJK Compatibility Ideographs Supplement
        0x30000, 0x323AF, // CJK Extensions G-H
    )
}
