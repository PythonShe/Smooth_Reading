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
        assertEquals(1, Graphemes.count("👩‍👩‍👧"))
    }
}
