package io.smoothreading.android

import android.graphics.Typeface
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.TextView
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.SpecWordSegmenter
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The Android snippets from `android/README.md`, verbatim where they can run
 * outside a composition, so the README cannot rot.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ReadmeSnippetsTest {

    private val textView: TextView
        get() = TextView(RuntimeEnvironment.getApplication())

    @Test
    fun `TextView snippet`() {
        val textView = textView
        textView.setSmoothText("Smooth reading works.")
        assertEquals(listOf("Smo", "read", "wor"), bold(textView.text as Spanned))

        textView.setSmoothText(
            "Smooth reading works.",
            SmoothOptions(fixation = 4, saccade = 1),
            restSpan = { ForegroundColorSpan(0x99000000.toInt()) },
        )
        assertEquals(listOf("Smoo", "readi", "wor"), bold(textView.text as Spanned))

        textView.text = SmoothReading.spanned("Smooth reading works.")
        assertEquals(listOf("Smo", "read", "wor"), bold(textView.text as Spanned))
    }

    @Test
    fun `Compose snippet (the non-composable part)`() {
        val body = "Smooth reading works."
        val annotated = SmoothReading.annotatedString(
            body,
            options = SmoothOptions(fixation = 3, saccade = 1),
            fixationStyle = SpanStyle(fontWeight = FontWeight.Bold),
            restStyle = SpanStyle(color = Color.Gray),
        )
        assertEquals(body, annotated.text)
        assertEquals(
            listOf("Smo", "oth", "read", "ing", "wor", "ks"),
            annotated.spanStyles.map { annotated.text.substring(it.start, it.end) },
        )
    }

    @Test
    fun `tokenizer snippet`() {
        assertEquals(
            "<b>我</b><b>喜</b>欢<b>阅</b>读",
            SmoothReading.toHtml("我喜欢阅读", segmenter = IcuWordSegmenter(Locale.CHINESE)),
        )
        assertEquals("<b>我喜欢</b>阅读", SmoothReading.toHtml("我喜欢阅读", segmenter = SpecWordSegmenter))
        assertEquals(listOf("我喜欢"), bold(SmoothReading.spanned("我喜欢阅读", SmoothOptions(), segmenter = SpecWordSegmenter)))
    }

    private fun bold(spanned: Spanned): List<String> =
        spanned.getSpans(0, spanned.length, StyleSpan::class.java)
            .filter { it.style == Typeface.BOLD }
            .sortedBy { spanned.getSpanStart(it) }
            .map { spanned.substring(spanned.getSpanStart(it), spanned.getSpanEnd(it)) }
}
