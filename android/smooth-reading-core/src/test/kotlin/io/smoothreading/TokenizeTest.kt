package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
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
    fun `a no-space-script run splits from the letters and digits around it`() {
        // One word per continuous run, never merged with an adjacent script.
        assertEquals(listOf("iPhone", "手机"), words("iPhone手机"))
        assertEquals(listOf("手机", "iPhone"), words("手机iPhone"))
        assertEquals(listOf("abc", "ก"), words("abcก"))
        assertEquals(listOf("ก", "abc"), words("กabc"))
        assertEquals(listOf("2024", "年"), words("2024年"))
        // Thai, Lao, Myanmar, Khmer and Hangul are no-space scripts too.
        assertEquals(listOf("ภาษาไทย", "abc"), words("ภาษาไทยabc"))
        assertEquals(listOf("ລາວ", "abc"), words("ລາວabc"))
        assertEquals(listOf("မြန်မာ", "abc"), words("မြန်မာabc"))
        assertEquals(listOf("ខ្មែរ", "abc"), words("ខ្មែរabc"))
        assertEquals(listOf("한국어", "abc"), words("한국어abc"))
        // Two no-space scripts next to each other are still one run.
        assertEquals(listOf("ก我"), words("ก我"))
    }

    @Test
    fun `a combining mark after a run character stays in the run`() {
        val marked = "我́"
        assertEquals(listOf(marked), words(marked))
        assertEquals(marked, SmoothReading.tokenize(marked).single().text)
        // A mark that follows a separator still belongs to the separator
        // (UAX #29 WB4): the emoji's variation selector is not a word.
        assertEquals(listOf("hi"), words("hi ❤️"))
    }

    @Test
    fun `run characters that are not letters, numbers or marks are separators`() {
        // U+30FB KATAKANA MIDDLE DOT sits inside the Katakana range but is
        // punctuation, so it separates two runs instead of joining them.
        assertEquals(listOf("ア", "イ"), words("ア・イ"))
    }

    @Test
    fun `an apostrophe never joins across a run boundary`() {
        assertEquals(listOf("it", "手机"), words("it'手机"))
        assertEquals(listOf("手机", "it"), words("手机'it"))
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
    fun `words off the saccade and without a fixation are plain`() {
        val off = SmoothReading.tokenize("one two", SmoothOptions(saccade = 2))[2] as SmoothToken.Word
        assertEquals(SmoothToken.Word("two", 0, "", "two"), off)
        val number = SmoothReading.tokenize("2024").single() as SmoothToken.Word
        assertEquals(SmoothToken.Word("2024", 0, "", "2024"), number)
    }

    @Test
    fun `tokens round-trip a custom segmenter's output`() {
        val everyChar = WordSegmenter { text -> text.map { RawSegment(it.toString(), it.isLetter()) } }
        val tokens = SmoothReading.tokenize("ab c", SmoothOptions(), everyChar)
        assertEquals("ab c", tokens.joinToString("") { it.text })
        assertEquals(listOf("a", "b", "c"), tokens.filterIsInstance<SmoothToken.Word>().map { it.fixationText })
    }
}
