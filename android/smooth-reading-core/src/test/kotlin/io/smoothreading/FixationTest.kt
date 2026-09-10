package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

/** Hand-derived cases from SPEC §2 (the example table and the special cases). */
class FixationTest {

    @ParameterizedTest(name = "{0} -> {1}")
    @CsvSource(
        "a, 1",
        "to, 1",
        "the, 2",
        "read, 2",
        "smooth, 3",
        "reading, 4",
        "2024, 0",
        "naïve, 3",
    )
    fun `spec table at default strength`(word: String, expected: Int) {
        assertEquals(expected, SmoothReading.fixationLength(word))
    }

    @ParameterizedTest(name = "strength {0} on \"reading\" -> {1}")
    @CsvSource(
        // round_half_up(7 * ratio): 1.4 -> 1, 2.45 -> 2, 3.5 -> 4, 4.55 -> 5, 5.6 -> 6
        "1, 1",
        "2, 2",
        "3, 4",
        "4, 5",
        "5, 6",
    )
    fun `every strength on a seven letter word`(strength: Int, expected: Int) {
        assertEquals(expected, SmoothReading.fixationLength("reading", 7, SmoothOptions(fixation = strength)))
    }

    @Test
    fun `round half up never rounds to zero`() {
        // round_half_up(2 * 0.20) = 0, clamped to 1.
        assertEquals(1, SmoothReading.fixationLength("to", 2, SmoothOptions(fixation = 1)))
    }

    @Test
    fun `single character needs strength three`() {
        assertEquals(0, SmoothReading.fixationLength("a", 1, SmoothOptions(fixation = 2)))
        assertEquals(1, SmoothReading.fixationLength("a", 1, SmoothOptions(fixation = 3)))
    }

    @Test
    fun `numbers are skipped unless asked for`() {
        assertEquals(0, SmoothReading.fixationLength("2024"))
        assertEquals(2, SmoothReading.fixationLength("2024", 4, SmoothOptions(emphasizeNumbers = true)))
        // A lone digit stays unemphasised even at strength 5: the number rule is
        // checked before the single-character rule (SPEC §2 ambiguity, resolved
        // the same way as the TypeScript core).
        assertEquals(0, SmoothReading.fixationLength("7", 1, SmoothOptions(fixation = 5)))
    }

    @Test
    fun `minWordLength suppresses short words`() {
        val options = SmoothOptions(minWordLength = 4)
        assertEquals(0, SmoothReading.fixationLength("the", 3, options))
        assertEquals(2, SmoothReading.fixationLength("read", 4, options))
    }

    @Test
    fun `apostrophes count as characters`() {
        assertEquals(3, SmoothReading.fixationLength("don't"))
    }

    @Test
    fun `override replaces the algorithm`() {
        val options = SmoothOptions(fixationLength = { _, graphemes, _ -> graphemes })
        assertEquals(6, SmoothReading.fixationLength("smooth", 6, options))
        // Out-of-range overrides are clamped to the word.
        val silly = SmoothOptions(fixationLength = { _, _, _ -> 99 })
        assertEquals(6, SmoothReading.fixationLength("smooth", 6, silly))
    }

    @Test
    fun `graphemes are counted as clusters not code units`() {
        // e + combining acute is one grapheme cluster.
        assertEquals(4, Graphemes.count("café"))
        assertEquals(1, Graphemes.count("👩\u200d👩\u200d👧"))
    }
    @Test
    fun `round half up uses the integer form of SPEC section 2`() {
        // 90 * 0.35 is 31.499999999999996 in binary floating point, so
        // floor(x + 0.5) would give 31; floor((90 * 35 + 50) / 100) gives 32.
        assertEquals(32, SmoothReading.fixationLength("x".repeat(90), 90, SmoothOptions(fixation = 2)))
        assertEquals(60, SmoothReading.fixationLength("x".repeat(170), 170, SmoothOptions(fixation = 2)))
        // Exact halves round up, not to even.
        assertEquals(2, SmoothReading.fixationLength("the", 3)) // 1.5 -> 2
        assertEquals(3, SmoothReading.fixationLength("naive", 5)) // 2.5 -> 3
        assertEquals(4, SmoothReading.fixationLength("x".repeat(10), 10, SmoothOptions(fixation = 2))) // 3.5 -> 4
    }

    @Test
    fun `only decimal digits count as numbers`() {
        assertEquals(0, SmoothReading.fixationLength("٤٢")) // Arabic-Indic digits
        assertEquals(1, SmoothReading.fixationLength("½", 1)) // fraction: not a digit
        assertEquals(1, SmoothReading.fixationLength("Ⅻ", 1)) // letter-number: not a digit
        assertEquals(2, SmoothReading.fixationLength("4th", 3))
    }

    @Test
    fun `out-of-range options are clamped, never rejected`() {
        // SPEC §4 guarantee 2, matching the TypeScript, Swift and Python ports.
        assertEquals(1, SmoothOptions(fixation = 0).fixation)
        assertEquals(1, SmoothOptions(fixation = -7).fixation)
        assertEquals(5, SmoothOptions(fixation = 6).fixation)
        assertEquals(5, SmoothOptions(fixation = Int.MAX_VALUE).fixation)
        assertEquals(1, SmoothOptions(saccade = 0).saccade)
        assertEquals(1, SmoothOptions(saccade = Int.MIN_VALUE).saccade)
        assertEquals(0, SmoothOptions(minWordLength = -1).minWordLength)
        // The clamped values are what the algorithm uses.
        assertEquals(1, SmoothReading.fixationLength("Smooth", options = SmoothOptions(fixation = 0)))
        assertEquals(5, SmoothReading.fixationLength("Smooth", options = SmoothOptions(fixation = 9)))
        assertEquals(
            "<b>S</b>mooth <b>r</b>eading",
            SmoothReading.toHtml("Smooth reading", SmoothOptions(fixation = -1, saccade = 0)),
        )
    }

    @Test
    fun `copy clamps like the constructor and keeps the other fields`() {
        val options = SmoothOptions(fixation = 4, minWordLength = 2, emphasizeNumbers = true)
        val copy = options.copy(fixation = 99)
        assertEquals(5, copy.fixation)
        assertEquals(2, copy.minWordLength)
        assertEquals(true, copy.emphasizeNumbers)
        assertEquals(options, options.copy())
        assertEquals(options.hashCode(), options.copy().hashCode())
    }
}
