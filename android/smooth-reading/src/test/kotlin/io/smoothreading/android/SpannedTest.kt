package io.smoothreading.android

import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.CharacterStyle
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Robolectric is only needed for `android.text`; the algorithm itself is tested in the core module. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SpannedTest {

    private inline fun <reified T : CharacterStyle> ranges(spanned: Spanned, noinline filter: (T) -> Boolean = { true }): List<String> =
        spanned.getSpans(0, spanned.length, T::class.java)
            .filter(filter)
            .sortedBy { spanned.getSpanStart(it) }
            .map { spanned.substring(spanned.getSpanStart(it), spanned.getSpanEnd(it)) }

    private fun boldRanges(spanned: Spanned): List<String> =
        ranges<StyleSpan>(spanned) { it.style == Typeface.BOLD }

    @Test
    fun `bold spans cover the fixation prefixes`() {
        val spanned: SpannableString = SmoothReading.spanned("Smooth reading works.")
        assertEquals("Smooth reading works.", spanned.toString())
        assertEquals(listOf("Smo", "read", "wor"), boldRanges(spanned))
        assertEquals(3, spanned.getSpans(0, spanned.length, Any::class.java).size)
    }

    @Test
    fun `numbers are not emphasised and saccade is honoured`() {
        val spanned = SmoothReading.spanned("one 2 three four", SmoothOptions(saccade = 2))
        assertEquals("one 2 three four", spanned.toString())
        assertEquals(listOf("on", "thr"), boldRanges(spanned))
    }

    @Test
    fun `rest spans cover the remainder of emphasised words only`() {
        val spanned = SmoothReading.spanned(
            "a 2024 reading",
            SmoothOptions(fixation = 2),
            restSpan = { ForegroundColorSpan(0x80000000.toInt()) },
        )
        // `a` has no fixation at strength 2 and `2024` is a number: neither gets any span.
        assertEquals(listOf("re"), boldRanges(spanned))
        assertEquals(listOf("ading"), ranges<ForegroundColorSpan>(spanned))
    }

    @Test
    fun `fixation span factory is used`() {
        val spanned = SmoothReading.spanned("read", fixationSpan = { StyleSpan(Typeface.ITALIC) })
        assertTrue(boldRanges(spanned).isEmpty())
        assertEquals(listOf("re"), ranges<StyleSpan>(spanned) { it.style == Typeface.ITALIC })
    }

    @Test
    fun `whole-word fixations get no empty rest span`() {
        val spanned = SmoothReading.spanned("a", restSpan = { ForegroundColorSpan(0) })
        assertEquals(listOf("a"), boldRanges(spanned))
        assertTrue(ranges<ForegroundColorSpan>(spanned).isEmpty())
    }

    @Test
    fun `the ICU tokenizer splits hyphenated words`() {
        val spanned = SmoothReading.spanned("well-known")
        assertEquals(listOf("we", "kno"), boldRanges(spanned))
    }

    @Test
    fun `combining marks and surrogate pairs keep offsets aligned`() {
        val text = "café 👋 naïve"
        val spanned = SmoothReading.spanned(text)
        assertEquals(text, spanned.toString())
        assertEquals(listOf("ca", "naï"), boldRanges(spanned))
    }
}
