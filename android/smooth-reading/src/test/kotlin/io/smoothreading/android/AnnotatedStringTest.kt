package io.smoothreading.android

import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AnnotatedStringTest {

    @Test
    fun `bold styles cover the fixation prefixes`() {
        val annotated = SmoothReading.annotatedString("Smooth reading works.")
        assertEquals("Smooth reading works.", annotated.text)
        val ranges = annotated.spanStyles.map { annotated.text.substring(it.start, it.end) to it.item }
        assertEquals(listOf("Smo", "read", "wor"), ranges.map { it.first })
        assertEquals(
            List(3) { SpanStyle(fontWeight = FontWeight.Bold) },
            ranges.map { it.second },
        )
    }

    @Test
    fun `rest style is applied when given`() {
        val rest = SpanStyle(fontWeight = FontWeight.Light)
        val annotated = SmoothReading.annotatedString(
            "reading",
            SmoothOptions(fixation = 1),
            restStyle = rest,
        )
        val ranges = annotated.spanStyles.map { annotated.text.substring(it.start, it.end) to it.item }
        assertEquals(listOf("r" to SpanStyle(fontWeight = FontWeight.Bold), "eading" to rest), ranges)
    }
}
