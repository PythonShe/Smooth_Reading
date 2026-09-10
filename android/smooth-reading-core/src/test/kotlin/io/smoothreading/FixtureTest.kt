package io.smoothreading

import java.io.File
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory

/**
 * The shared cross-port fixtures (SPEC §7).
 *
 * Every JSON file under `fixtures/common` must pass in every port; the files
 * under `fixtures/segmenter` only where the tokenizer is ICU-backed, which for
 * this project means Android (`android.icu.text.BreakIterator`) and not a plain
 * JDK — see [WordSegmenter].
 * Both directories are skipped as *assumptions*, not failures, when they are
 * absent or empty, so the build still works in a checkout without them.
 */
class FixtureTest {

    @TestFactory
    fun common(): List<DynamicTest> = cases("common", SmoothReading.defaultSegmenter())

    @TestFactory
    fun segmenter(): List<DynamicTest> {
        assumeTrue(icuIsAvailable(), "no ICU word breaker on this runtime (JDK BreakIterator is rule-based)")
        return cases("segmenter", BreakIteratorWordSegmenter())
    }

    private fun cases(directory: String, segmenter: WordSegmenter): List<DynamicTest> {
        val dir = fixturesRoot().resolve(directory)
        assumeTrue(dir.isDirectory, "fixtures directory not present: $dir")
        val files = dir.listFiles { file -> file.isFile && file.extension == "json" }
            ?.sortedBy { it.name }
            .orEmpty()
        assumeTrue(files.isNotEmpty(), "no fixture files in $dir")

        return files.flatMap { file ->
            val cases = JSONArray(file.readText())
            (0 until cases.length()).map { index ->
                val case = cases.getJSONObject(index)
                val name = case.optString("name", "case $index")
                DynamicTest.dynamicTest("${file.name} :: $name") {
                    val html = SmoothReading.toHtml(
                        case.getString("input"),
                        htmlOptions(case.optJSONObject("options")),
                        segmenter,
                    )
                    assertEquals(case.getString("html"), html)
                }
            }
        }
    }

    /**
     * A fixture's `options` object carries both the fixation options of
     * SPEC §4 and the HTML options, flattened into one object.
     */
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
                locale = json.optString("locale", null)?.let { Locale.forLanguageTag(it) },
            ),
            tag = json.optString("tag", htmlDefaults.tag),
            className = json.optString("className", null),
            restTag = json.optString("restTag", null),
            restClassName = json.optString("restClassName", null),
            ignoreHtmlTags = json.optBoolean("ignoreHtmlTags", htmlDefaults.ignoreHtmlTags),
            skipTags = json.optJSONArray("skipTags")
                ?.let { array -> (0 until array.length()).map { array.getString(it) } }
                ?: htmlDefaults.skipTags,
        )
    }

    private fun fixturesRoot(): File {
        val configured = System.getProperty("smoothreading.fixtures")
        if (configured != null) return File(configured)
        // ../../fixtures relative to this module's project directory.
        return File("..").resolve("../fixtures").normalize()
    }

    /**
     * `true` when `java.text.BreakIterator` is the ICU implementation: only ICU
     * follows UAX #29 and splits `well-known` in two.
     */
    private fun icuIsAvailable(): Boolean =
        BreakIteratorWordSegmenter().segment("well-known").count { it.isWord } == 2
}
