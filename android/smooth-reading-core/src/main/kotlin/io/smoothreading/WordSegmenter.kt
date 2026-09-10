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
 *   `[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*` plus the scriptio-continua
 *   rule. It is the default and the only tokenizer guaranteed to agree with
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
 * The tokenizer of SPEC §3's fallback: maximal runs of `\p{L}\p{N}\p{M}`
 * joined by `'` or `’`, with runs of scriptio-continua scripts (Han, Kana,
 * Hangul, Thai) forming words of their own. Hand-written rather than
 * regex-driven so that the CJK rule and the regex share one linear pass.
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
                isContinuous(cp) -> scanRun(text, i)
                isWordChar(cp) -> scanWord(text, i)
                else -> {
                    i += Character.charCount(cp)
                    continue
                }
            }
            if (separatorStart < i) out.add(RawSegment(text.substring(separatorStart, i), isWord = false))
            out.add(RawSegment(text.substring(i, end), isWord = true))
            i = end
            separatorStart = end
        }
        if (separatorStart < text.length) out.add(RawSegment(text.substring(separatorStart), isWord = false))
        return out
    }

    /** Consume a run of scriptio-continua code points starting at [from]. */
    private fun scanRun(text: String, from: Int): Int {
        var i = from
        while (i < text.length) {
            val cp = text.codePointAt(i)
            if (!isContinuous(cp)) break
            i += Character.charCount(cp)
        }
        return i
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
            if ((cp == '\''.code || cp == '’'.code) && i + 1 < text.length) {
                val after = text.codePointAt(i + 1)
                if (isWordChar(after) && !isContinuous(after)) {
                    i += 1
                    continue
                }
            }
            break
        }
        return i
    }

    /** `\p{L}`, `\p{N}` or `\p{M}`. */
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
