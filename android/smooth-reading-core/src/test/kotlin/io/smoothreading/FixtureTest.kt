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
 * Every JSON file under `fixtures/common` must pass in every port. The files
 * under `fixtures/segmenter` need an ICU word breaker and run in the Android
 * module (`AndroidFixtureTest`) against `IcuWordSegmenter`.
 * A missing or empty directory is skipped as an *assumption*, not a failure,
 * so the build still works in a checkout without it.
 */
class FixtureTest {

    @TestFactory
    fun common(): List<DynamicTest> = cases("common")

    private fun cases(directory: String): List<DynamicTest> {
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
}
