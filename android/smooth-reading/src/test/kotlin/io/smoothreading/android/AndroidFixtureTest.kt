package io.smoothreading.android

import io.smoothreading.HtmlOptions
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.WordSegmenter
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The shared cross-port fixtures (SPEC §7), run on Android.
 *
 * `common` runs through the default spec tokenizer, `segmenter` through
 * [IcuWordSegmenter] — the ICU word breaker this artifact ships with. Missing
 * fixture directories are skipped as assumptions, not failures.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AndroidFixtureTest {

    @Test
    fun common() {
        runFixtures("common", SmoothReading.defaultSegmenter())
    }

    @Test
    fun commonWithIcu() {
        runFixtures("common", IcuWordSegmenter())
    }

    @Test
    fun segmenter() {
        runFixtures("segmenter", IcuWordSegmenter())
    }

    private fun runFixtures(directory: String, segmenter: WordSegmenter) {
        val dir = fixturesRoot().resolve(directory)
        assumeTrue("fixtures directory not present: $dir", dir.isDirectory)
        val files = dir.listFiles { file -> file.isFile && file.extension == "json" }
            ?.sortedBy { it.name }
            .orEmpty()
        assumeTrue("no fixture files in $dir", files.isNotEmpty())

        for (file in files) {
            val cases = JSONArray(file.readText())
            for (index in 0 until cases.length()) {
                val case = cases.getJSONObject(index)
                val html = SmoothReading.toHtml(
                    case.getString("input"),
                    htmlOptions(case.optJSONObject("options")),
                    segmenter,
                )
                assertEquals(
                    "${file.name} :: ${case.optString("name", "case $index")}",
                    case.getString("html"),
                    html,
                )
            }
        }
    }

    private fun htmlOptions(json: JSONObject?): HtmlOptions {
        if (json == null) return HtmlOptions()
        val smoothDefaults = SmoothOptions()
        val htmlDefaults = HtmlOptions()
        return HtmlOptions(
            smooth = SmoothOptions(
                fixation = json.optInt("fixation", smoothDefaults.fixation),
                saccade = json.optInt("saccade", smoothDefaults.saccade),
                minWordLength = json.optInt("minWordLength", smoothDefaults.minWordLength),
                emphasizeNumbers = json.optBoolean("emphasizeNumbers", smoothDefaults.emphasizeNumbers),
            ),
            tag = json.optString("tag", htmlDefaults.tag),
            className = json.optStringOrNull("className"),
            restTag = json.optStringOrNull("restTag"),
            restClassName = json.optStringOrNull("restClassName"),
            ignoreHtmlTags = json.optBoolean("ignoreHtmlTags", htmlDefaults.ignoreHtmlTags),
            skipTags = json.optJSONArray("skipTags")
                ?.let { array -> (0 until array.length()).map { array.getString(it) } }
                ?: htmlDefaults.skipTags,
        )
    }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

    private fun fixturesRoot(): File {
        val configured = System.getProperty("smoothreading.fixtures")
        if (configured != null) return File(configured)
        return File("..").resolve("../fixtures").normalize()
    }
}
