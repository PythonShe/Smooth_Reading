package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class HtmlTest {

    @Test
    fun `default rendering (SPEC section 7 example)`() {
        assertEquals(
            "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.",
            SmoothReading.toHtml("Smooth reading works."),
        )
    }

    @Test
    fun `hyphenated words are two words`() {
        assertEquals("<b>we</b>ll-<b>kno</b>wn", SmoothReading.toHtml("well-known"))
    }

    @Test
    fun `custom tag, class and rest tag`() {
        val options = HtmlOptions(
            tag = "span",
            className = "sr-fixation",
            restTag = "span",
            restClassName = "sr-rest",
        )
        assertEquals(
            "<span class=\"sr-fixation\">re</span><span class=\"sr-rest\">ad</span>",
            SmoothReading.toHtml("read", options),
        )
    }

    @Test
    fun `text is escaped`() {
        assertEquals(
            "2 &lt; 3 &amp; &quot;4&quot;",
            SmoothReading.toHtml("2 < 3 & \"4\"", HtmlOptions(ignoreHtmlTags = false)),
        )
    }

    @Test
    fun `existing markup is passed through verbatim`() {
        assertEquals(
            "<p class=\"x\"><b>re</b>ad</p>",
            SmoothReading.toHtml("<p class=\"x\">read</p>"),
        )
    }

    @Test
    fun `skip tags are left alone`() {
        assertEquals(
            "<code>reading</code> <b>read</b>ing",
            SmoothReading.toHtml("<code>reading</code> reading"),
        )
    }

    @Test
    fun `already emphasised markup is not wrapped twice`() {
        assertEquals("<b>Smo</b>", SmoothReading.toHtml("<b>Smo</b>"))
    }

    @Test
    fun `output is stable`() {
        val input = "Smooth <em>reading</em> works."
        assertEquals(SmoothReading.toHtml(input), SmoothReading.toHtml(input))
    }

    @Test
    fun `saccade survives across tags`() {
        // one(0) two(1, skipped) three(2) — the <em> in the middle must not
        // restart the counter.
        assertEquals(
            "<b>on</b>e <em>two</em> <b>thr</b>ee",
            SmoothReading.toHtml("one <em>two</em> three", HtmlOptions(SmoothOptions(saccade = 2))),
        )
    }

    @Test
    fun `smooth-only overload keeps the default tag`() {
        assertEquals("<b>read</b>ing", SmoothReading.toHtml("reading", SmoothOptions(fixation = 3)))
    }
}
