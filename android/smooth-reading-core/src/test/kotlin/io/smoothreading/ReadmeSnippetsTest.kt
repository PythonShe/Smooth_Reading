package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** The JVM snippets from `android/README.md`, verbatim, so the README cannot rot. */
class ReadmeSnippetsTest {

    @Test
    fun `html snippet`() {
        assertEquals(
            "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.",
            SmoothReading.toHtml("Smooth reading works."),
        )
        assertEquals(
            "<span class=\"sr-fixation\">Smoo</span>th <span class=\"sr-fixation\">readi</span>ng <span class=\"sr-fixation\">wor</span>ks.",
            SmoothReading.toHtml(
                "Smooth reading works.",
                HtmlOptions(SmoothOptions(fixation = 4), tag = "span", className = "sr-fixation"),
            ),
        )
    }

    @Test
    fun `tokens snippet`() {
        val lines = mutableListOf<String>()
        SmoothReading.tokenize("well-known").forEach { token ->
            when (token) {
                is SmoothToken.Word -> lines += "${token.fixationText}|${token.restText}"
                is SmoothToken.Separator -> lines += "sep ${token.text}"
            }
        }
        assertEquals(listOf("we|ll", "sep -", "kno|wn"), lines)
    }

    @Test
    fun `override snippet`() {
        val firstHalf = SmoothOptions(fixationLength = { _, graphemes, _ -> graphemes / 2 })
        assertEquals("<b>rea</b>ding", SmoothReading.toHtml("reading", firstHalf))
    }
}
