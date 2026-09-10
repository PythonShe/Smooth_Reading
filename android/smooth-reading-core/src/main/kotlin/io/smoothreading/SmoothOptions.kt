package io.smoothreading

import java.util.Locale

/**
 * Options for the fixation/segmentation layer (SPEC §4).
 *
 * Every field has the default the spec prescribes, so `SmoothOptions()` is the
 * "resolved" option set that is handed to [fixationLength] overrides.
 *
 * Out-of-range values are **clamped, never rejected** (SPEC §4, behavioural
 * guarantee 2), exactly as in the TypeScript, Swift and Python ports: the
 * properties always hold an in-range value, whatever the caller passed.
 *
 * @property fixation fixation strength, clamped to `1..5`. Default `3`.
 * @property saccade which words get a fixation: `1` = every word, `2` = every
 *   second word, … Clamped to `>= 1`. Default `1`.
 * @property minWordLength words shorter than this (in grapheme clusters) get no
 *   fixation. Clamped to `>= 0`. Default `1`.
 * @property emphasizeNumbers whether words made only of digits are emphasised.
 *   Default `false`.
 * @property locale locale handed to the break iterators. `null` = runtime
 *   default.
 * @property fixationLength optional override that replaces the default
 *   algorithm of SPEC §2 entirely. It receives the word, its grapheme count and
 *   these options, and returns how many grapheme clusters to emphasise.
 */
public class SmoothOptions(
    fixation: Int = 3,
    saccade: Int = 1,
    minWordLength: Int = 1,
    public val emphasizeNumbers: Boolean = false,
    public val locale: Locale? = null,
    public val fixationLength: ((word: String, graphemes: Int, options: SmoothOptions) -> Int)? = null,
) {
    /** Fixation strength, clamped into `1..5`. */
    public val fixation: Int = fixation.coerceIn(1, 5)

    /** Saccade interval, clamped to `>= 1`. */
    public val saccade: Int = saccade.coerceAtLeast(1)

    /** Minimum word length, clamped to `>= 0`. */
    public val minWordLength: Int = minWordLength.coerceAtLeast(0)

    /**
     * A copy with the given fields replaced; the replacements are clamped like
     * the constructor's.
     */
    public fun copy(
        fixation: Int = this.fixation,
        saccade: Int = this.saccade,
        minWordLength: Int = this.minWordLength,
        emphasizeNumbers: Boolean = this.emphasizeNumbers,
        locale: Locale? = this.locale,
        fixationLength: ((word: String, graphemes: Int, options: SmoothOptions) -> Int)? = this.fixationLength,
    ): SmoothOptions = SmoothOptions(
        fixation = fixation,
        saccade = saccade,
        minWordLength = minWordLength,
        emphasizeNumbers = emphasizeNumbers,
        locale = locale,
        fixationLength = fixationLength,
    )

    public operator fun component1(): Int = fixation

    public operator fun component2(): Int = saccade

    public operator fun component3(): Int = minWordLength

    public operator fun component4(): Boolean = emphasizeNumbers

    public operator fun component5(): Locale? = locale

    public operator fun component6(): ((word: String, graphemes: Int, options: SmoothOptions) -> Int)? =
        fixationLength

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SmoothOptions) return false
        return fixation == other.fixation &&
            saccade == other.saccade &&
            minWordLength == other.minWordLength &&
            emphasizeNumbers == other.emphasizeNumbers &&
            locale == other.locale &&
            fixationLength == other.fixationLength
    }

    override fun hashCode(): Int {
        var result = fixation
        result = 31 * result + saccade
        result = 31 * result + minWordLength
        result = 31 * result + emphasizeNumbers.hashCode()
        result = 31 * result + (locale?.hashCode() ?: 0)
        result = 31 * result + (fixationLength?.hashCode() ?: 0)
        return result
    }

    override fun toString(): String =
        "SmoothOptions(fixation=$fixation, saccade=$saccade, minWordLength=$minWordLength, " +
            "emphasizeNumbers=$emphasizeNumbers, locale=$locale, fixationLength=$fixationLength)"

    public companion object {
        /** The defaults of SPEC §4 (`defaults` in the TypeScript core). */
        @JvmField
        public val DEFAULTS: SmoothOptions = SmoothOptions()
    }
}
