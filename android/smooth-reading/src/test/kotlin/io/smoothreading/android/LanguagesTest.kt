package io.smoothreading.android

import io.smoothreading.HtmlOptions
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.SmoothToken
import io.smoothreading.SpecWordSegmenter
import io.smoothreading.WordSegmenter
import java.io.File
import java.util.Locale
import org.hamcrest.CoreMatchers.equalTo
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ErrorCollector
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Multilingual and bidi guarantees over every fixture input, the Android
 * counterpart of the Swift port's `LanguagesTests` (`docs/LANGUAGES.md`).
 *
 * Beyond matching the expected HTML (see [AndroidFixtureTest]), every input of
 * `fixtures/common` and `fixtures/segmenter` must satisfy three invariants
 * with both word breakers: tokens and attributed strings are lossless, the
 * markup adds nothing but emphasis tags, and no `dir` attribute or bidi
 * control character is introduced. Failures are collected so one run reports
 * every offending case.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LanguagesTest {

    @get:Rule
    val errors: ErrorCollector = ErrorCollector()

    private class Fixture(val label: String, val input: String, val options: JSONObject?)

    private val segmenters: List<Pair<String, WordSegmenter>> =
        listOf("SpecWordSegmenter" to SpecWordSegmenter, "IcuWordSegmenter" to IcuWordSegmenter())

    @Test
    fun tokensAreLossless() {
        forEachCase { fixture, options, segmenterName, segmenter ->
            val tokens = SmoothReading.tokenize(fixture.input, options, segmenter)
            check("${fixture.label} [$segmenterName] tokens", tokens.joinToString("") { it.text }, fixture.input)
            for (token in tokens) {
                if (token is SmoothToken.Word) {
                    check("${fixture.label} [$segmenterName] word ${token.text}", token.fixationText + token.restText, token.text)
                }
            }
        }
    }

    @Test
    fun attributedStringsPreserveTheInputAndInsertNoBidiControls() {
        forEachCase { fixture, options, segmenterName, segmenter ->
            val label = "${fixture.label} [$segmenterName]"
            val expectedControls = bidiControlCount(fixture.input)

            val spanned = SmoothReading.spanned(fixture.input, options, segmenter = segmenter)
            check("$label spanned", spanned.toString(), fixture.input)
            check("$label spanned bidi controls", bidiControlCount(spanned.toString()), expectedControls)

            val annotated = SmoothReading.annotatedString(fixture.input, options, segmenter = segmenter)
            check("$label annotatedString", annotated.text, fixture.input)
            check("$label annotatedString bidi controls", bidiControlCount(annotated.text), expectedControls)
        }
    }

    @Test
    fun markupAddsNothingButEmphasisTags() {
        forEachCase { fixture, options, segmenterName, segmenter ->
            val label = "${fixture.label} [$segmenterName]"
            val html = htmlOptions(fixture.options, options)
            val rendered = SmoothReading.toHtml(fixture.input, html, segmenter)

            // The same render with every fixation suppressed adds no emphasis
            // tags of its own (the input may already contain some, hence
            // stripping both sides).
            val plain = SmoothReading.toHtml(
                fixture.input,
                html.copy(smooth = options.copy(fixationLength = { _, _, _ -> 0 })),
                segmenter,
            )
            val emphasis = listOfNotNull(html.tag, html.restTag)
            check("$label markup", stripEmphasis(rendered, emphasis), stripEmphasis(plain, emphasis))
            if (!html.ignoreHtmlTags || fixture.input.none { it == '<' || it == '&' }) {
                check("$label plain render", plain, escapeHtml(fixture.input))
            }
        }
    }

    @Test
    fun noDirAttributeOrBidiControlIsAdded() {
        forEachCase { fixture, options, segmenterName, segmenter ->
            val label = "${fixture.label} [$segmenterName]"
            val rendered = SmoothReading.toHtml(fixture.input, htmlOptions(fixture.options, options), segmenter)
            check("$label dir attributes", rendered.windowed(4).count { it == "dir=" }, fixture.input.windowed(4).count { it == "dir=" })
            check("$label bidi controls", bidiControlCount(rendered), bidiControlCount(fixture.input))
        }
    }

    // ---- helpers -------------------------------------------------------------

    private fun <T> check(reason: String, actual: T, expected: T) {
        errors.checkThat(reason, actual, equalTo(expected))
    }

    private fun forEachCase(action: (Fixture, SmoothOptions, String, WordSegmenter) -> Unit) {
        val cases = allCases()
        for (fixture in cases) {
            val options = smoothOptions(fixture.options)
            for ((name, segmenter) in segmenters) action(fixture, options, name, segmenter)
        }
    }

    /** Every case of both suites, labelled `suite/file: name`. */
    private fun allCases(): List<Fixture> {
        val out = ArrayList<Fixture>()
        for (suite in listOf("common", "segmenter")) {
            val dir = fixturesRoot().resolve(suite)
            assumeTrue("fixtures directory not present: $dir", dir.isDirectory)
            val files = dir.listFiles { file -> file.isFile && file.extension == "json" }
                ?.sortedBy { it.name }
                .orEmpty()
            for (file in files) {
                val cases = JSONArray(file.readText())
                for (index in 0 until cases.length()) {
                    val case = cases.getJSONObject(index)
                    out.add(
                        Fixture(
                            "$suite/${file.name}: ${case.optString("name", "case $index")}",
                            case.getString("input"),
                            case.optJSONObject("options"),
                        ),
                    )
                }
            }
        }
        assertTrue("expected the scripts, cjk-extended and bidi fixtures to be present", out.size > 100)
        return out
    }

    private fun smoothOptions(json: JSONObject?): SmoothOptions {
        val defaults = SmoothOptions()
        if (json == null) return defaults
        return SmoothOptions(
            fixation = json.optInt("fixation", defaults.fixation),
            saccade = json.optInt("saccade", defaults.saccade),
            minWordLength = json.optInt("minWordLength", defaults.minWordLength),
            emphasizeNumbers = json.optBoolean("emphasizeNumbers", defaults.emphasizeNumbers),
            locale = json.optStringOrNull("locale")?.let { Locale.forLanguageTag(it) },
        )
    }

    private fun htmlOptions(json: JSONObject?, smooth: SmoothOptions): HtmlOptions {
        val defaults = HtmlOptions()
        if (json == null) return HtmlOptions(smooth)
        return HtmlOptions(
            smooth = smooth,
            tag = json.optString("tag", defaults.tag),
            className = json.optStringOrNull("className"),
            restTag = json.optStringOrNull("restTag"),
            restClassName = json.optStringOrNull("restClassName"),
            ignoreHtmlTags = json.optBoolean("ignoreHtmlTags", defaults.ignoreHtmlTags),
            skipTags = json.optJSONArray("skipTags")
                ?.let { array -> (0 until array.length()).map { array.getString(it) } }
                ?: defaults.skipTags,
        )
    }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

    private fun fixturesRoot(): File {
        val configured = System.getProperty("smoothreading.fixtures")
        if (configured != null) return File(configured)
        return File("..").resolve("../fixtures").normalize()
    }

    private companion object {
        /** LRM, RLM, ALM, the explicit embeddings/overrides and the isolates. */
        val BIDI_CONTROLS: Set<Int> =
            setOf(0x200E, 0x200F, 0x061C) + (0x202A..0x202E).toSet() + (0x2066..0x2069).toSet()

        fun bidiControlCount(text: String): Int = text.codePoints().filter { it in BIDI_CONTROLS }.count().toInt()

        fun stripEmphasis(markup: String, tags: List<String>): String {
            val names = tags.joinToString("|") { Regex.escape(it) }
            return markup.replace(Regex("</?(?:$names)(?:\\s[^>]*)?>"), "")
        }

        fun escapeHtml(text: String): String =
            text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
    }
}
