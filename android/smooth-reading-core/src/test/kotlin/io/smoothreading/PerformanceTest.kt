package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Sanity check that the renderer is linear: 1 MB must finish well under a second. */
class PerformanceTest {

    private val megabyte: String = buildString {
        val paragraph = "Smooth reading works, don't stop &amp; <em>keep</em> going; well-known text 2024. "
        while (length < 1 shl 20) append(paragraph)
    }

    @Test
    fun `one megabyte renders well under a second`() {
        SmoothReading.toHtml(megabyte) // warm up
        val started = System.nanoTime()
        val html = SmoothReading.toHtml(megabyte)
        val tokens = SmoothReading.tokenize(megabyte)
        val elapsedMs = (System.nanoTime() - started) / 1_000_000
        assertTrue(html.length > megabyte.length)
        assertEquals(megabyte, tokens.joinToString("") { it.text })
        assertTrue(elapsedMs < 1000) { "1 MB took $elapsedMs ms" }
    }
}
