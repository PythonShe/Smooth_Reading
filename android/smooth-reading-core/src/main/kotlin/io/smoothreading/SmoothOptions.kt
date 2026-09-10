package io.smoothreading

import java.util.Locale

/**
 * Options for the fixation/segmentation layer (SPEC §4).
 *
 * Every field has the default the spec prescribes, so `SmoothOptions()` is the
 * "resolved" option set that is handed to [fixationLength] overrides.
 *
 * @property fixation fixation strength, `1..5`. Default `3`.
 * @property saccade which words get a fixation: `1` = every word, `2` = every
 *   second word, … Must be `>= 1`. Default `1`.
 * @property minWordLength words shorter than this (in grapheme clusters) get no
 *   fixation. Default `1`.
 * @property emphasizeNumbers whether words made only of digits are emphasised.
 *   Default `false`.
 * @property locale locale handed to the break iterators. `null` = runtime
 *   default.
 * @property fixationLength optional override that replaces the default
 *   algorithm of SPEC §2 entirely. It receives the word, its grapheme count and
 *   these options, and returns how many grapheme clusters to emphasise.
 */
public data class SmoothOptions(
    val fixation: Int = 3,
    val saccade: Int = 1,
    val minWordLength: Int = 1,
    val emphasizeNumbers: Boolean = false,
    val locale: Locale? = null,
    val fixationLength: ((word: String, graphemes: Int, options: SmoothOptions) -> Int)? = null,
) {
    init {
        require(fixation in 1..5) { "fixation must be in 1..5, was $fixation" }
        require(saccade >= 1) { "saccade must be >= 1, was $saccade" }
        require(minWordLength >= 0) { "minWordLength must be >= 0, was $minWordLength" }
    }

    public companion object {
        /** The defaults of SPEC §4 (`defaults` in the TypeScript core). */
        @JvmField
        public val DEFAULTS: SmoothOptions = SmoothOptions()
    }
}
