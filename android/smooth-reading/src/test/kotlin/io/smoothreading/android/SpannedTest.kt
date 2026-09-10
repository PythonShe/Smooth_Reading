package io.smoothreading.android

import android.graphics.Typeface
import android.text.Spanned
import android.text.style.StyleSpan
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Robolectric is only needed for `android.text`; the algorithm itself is tested in the core module. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SpannedTest {

    private fun boldRanges(spanned: Spanned): List<String> =
        spanned.getSpans(0, spanned.length, StyleSpan::class.java)
            .filter { it.style == Typeface.BOLD }
            .sortedBy { spanned.getSpanStart(it) }
            .map { spanned.substring(spanned.getSpanStart(it), spanned.getSpanEnd(it)) }

    @Test
    fun `bold spans cover the fixation prefixes`() {
        val spanned = SmoothReading.spanned("Smooth reading works.")
        assertEquals("Smooth reading works.", spanned.toString())
        assertEquals(listOf("Smo", "read", "wor"), boldRanges(spanned))
    }

    @Test
    fun `numbers are not emphasised and saccade is honoured`() {
        val spanned = SmoothReading.spanned("one 2 three four", SmoothOptions(saccade = 2))
        assertEquals("one 2 three four", spanned.toString())
        assertEquals(listOf("on", "thr"), boldRanges(spanned))
    }

    @Test
    fun `the ICU tokenizer splits hyphenated words`() {
        val spanned = SmoothReading.spanned("well-known")
        assertEquals(listOf("we", "kno"), boldRanges(spanned))
    }
}
