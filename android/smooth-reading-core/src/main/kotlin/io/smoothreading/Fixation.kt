package io.smoothreading

/**
 * The fixation-length algorithm of SPEC §2.
 *
 * The ratios are expressed in *percent* so the whole computation is integer
 * arithmetic: `floor(n * 0.35 + 0.5)` is representation dependent near .5
 * boundaries, `floor((n * 35 + 50) / 100)` is not. This mirrors the TypeScript
 * core exactly, which is what keeps the shared fixtures byte-identical.
 */
internal object Fixation {

    private val RATIO_PERCENT = intArrayOf(0, 20, 35, 50, 65, 80)

    private val ALL_DIGITS = Regex("^\\p{N}+$")

    /** `true` when the word consists entirely of digits (SPEC §2 rule 3). */
    fun isNumeric(word: String): Boolean = word.isNotEmpty() && ALL_DIGITS.matches(word)

    /** `round_half_up(n * ratio)` from SPEC §2, in exact integer arithmetic. */
    fun roundHalfUpRatio(graphemes: Int, fixation: Int): Int {
        val percent = RATIO_PERCENT[if (fixation in 1..5) fixation else 3]
        return Math.floorDiv(graphemes * percent + 50, 100)
    }

    /**
     * The default algorithm. The order of the special cases follows the
     * TypeScript core: numbers and [SmoothOptions.minWordLength] are checked
     * before the single-character rule, so a lone digit is never emphasised.
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
