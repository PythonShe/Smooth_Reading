package io.smoothreading

/**
 * The fixation-length algorithm of SPEC §2.
 *
 * The ratios are expressed in *percent* so the whole computation is integer
 * arithmetic: `floor(n * 0.35 + 0.5)` drifts below the true value for some
 * `n` (90 × 0.35 is 31.499999… in binary floating point), while
 * `floor((n * 35 + 50) / 100)` is exact. This is the form the spec prescribes
 * and what keeps the shared fixtures byte-identical across ports.
 */
internal object Fixation {

    /** Index = fixation strength `1..5`; index 0 is unused. */
    private val RATIO_PERCENT = intArrayOf(0, 20, 35, 50, 65, 80)

    /**
     * `true` when [word] is made only of decimal digits (`\p{Nd}` in any
     * script, SPEC §2 rule 1). Fractions such as `½` and letter-numbers such as
     * `Ⅻ` are *not* digits, matching the TypeScript core.
     */
    fun isNumeric(word: String): Boolean {
        if (word.isEmpty()) return false
        var i = 0
        while (i < word.length) {
            val cp = word.codePointAt(i)
            if (Character.getType(cp) != Character.DECIMAL_DIGIT_NUMBER.toInt()) return false
            i += Character.charCount(cp)
        }
        return true
    }

    /** `round_half_up(n * ratio)` from SPEC §2, in exact integer arithmetic. */
    fun roundHalfUpRatio(graphemes: Int, fixation: Int): Int =
        (graphemes * RATIO_PERCENT[fixation] + 50) / 100

    /**
     * The default algorithm. Suppression rules (numbers, `minWordLength`) come
     * first, then the single-character rule, then the ratio formula.
     */
    fun default(word: String, graphemes: Int, options: SmoothOptions): Int {
        val n = graphemes
        if (n <= 0) return 0
        if (!options.emphasizeNumbers && isNumeric(word)) return 0
        if (n < options.minWordLength) return 0
        if (n == 1) return if (options.fixation >= 3) 1 else 0
        return roundHalfUpRatio(n, options.fixation).coerceIn(1, n)
    }
}
