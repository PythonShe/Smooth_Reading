package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class TokenizeTest {

    private fun words(text: String, options: SmoothOptions = SmoothOptions()) =
        SmoothReading.tokenize(text, options).filterIsInstance<SmoothToken.Word>().map { it.text }

    @Test
    fun `apostrophes join, hyphens split (SPEC section 3)`() {
        assertEquals(listOf("don't"), words("don't"))
        assertEquals(listOf("don’t"), words("don’t"))
        assertEquals(listOf("well", "known"), words("well-known"))
        assertEquals(listOf("text", "vide"), words("text-vide"))
    }

    @Test
    fun `separators are merged and round-trip`() {
        val tokens = SmoothReading.tokenize("Hi,  there!")
        assertEquals(
            listOf<SmoothToken>(
                SmoothToken.Word("Hi", 1, "H", "i"),
                SmoothToken.Separator(",  "),
                SmoothToken.Word("there", 3, "the", "re"),
                SmoothToken.Separator("!"),
            ),
            tokens,
        )
        assertEquals("Hi,  there!", tokens.joinToString("") { it.text })
    }

    @Test
    fun `CJK runs are single words (SPEC section 3)`() {
        assertEquals(listOf("中文测试", "abc"), words("中文测试abc"))
        val token = SmoothReading.tokenize("中文测试").first() as SmoothToken.Word
        assertEquals(2, token.fixation)
        assertEquals("中文", token.fixationText)
    }

    @Test
    fun `saccade counts every word including numbers`() {
        val options = SmoothOptions(saccade = 2)
        val emphasised = SmoothReading.tokenize("one two three four", options)
            .filterIsInstance<SmoothToken.Word>()
            .map { it.fixationText }
        assertEquals(listOf("on", "", "thr", ""), emphasised)

        val withNumber = SmoothReading.tokenize("1 two three", options)
            .filterIsInstance<SmoothToken.Word>()
            .map { it.fixationText }
        // "1" is on the saccade boundary but is a number, "two" is skipped by
        // the saccade, "three" is back on the boundary.
        assertEquals(listOf("", "", "thr"), withNumber)
    }

    @Test
    fun `combining marks stay with their base character`() {
        // c, a, f, e + U+0301 COMBINING ACUTE = 4 grapheme clusters
        val decomposed = "caf" + "e\u0301"
        val token = SmoothReading.tokenize(decomposed).first() as SmoothToken.Word
        assertEquals(4, Graphemes.count(decomposed))
        assertEquals(2, token.fixation)
        assertEquals("ca", token.fixationText)
        assertEquals("f" + "e\u0301", token.restText)
    }

    @Test
    fun `the default tokenizer is the spec one, not the JDK break iterator`() {
        // Documented in WordSegmenter: the JDK's rule-based iterator keeps
        // "well-known" as one word, which the spec forbids. On Android the same
        // class is ICU-backed and does split it.
        assertEquals(SpecWordSegmenter, SmoothReading.defaultSegmenter())
        val breakIterator = BreakIteratorWordSegmenter()
            .segment("well-known")
            .filter { it.isWord }
            .map { it.text }
        assertTrue(breakIterator == listOf("well-known") || breakIterator == listOf("well", "known")) {
            "unexpected break-iterator behaviour: $breakIterator"
        }
    }
}
