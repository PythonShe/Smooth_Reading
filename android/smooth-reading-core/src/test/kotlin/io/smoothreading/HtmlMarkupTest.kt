package io.smoothreading

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

/**
 * SPEC §4 markup rules: character references, what counts as a tag, the
 * `skipTags` semantics (including the implicit `tag` / `restTag` skip) and
 * words without a fixation. Expectations mirror the Swift port's
 * `HtmlMarkupTests` so the ports cannot drift apart.
 */
class HtmlMarkupTest {

    private fun html(text: String, ignoreHtmlTags: Boolean = true): String =
        SmoothReading.toHtml(text, HtmlOptions(ignoreHtmlTags = ignoreHtmlTags))

    // --- Character references -------------------------------------------

    @Test
    fun `existing references pass through verbatim`() {
        assertEquals("<b>To</b>m &amp; <b>Jer</b>ry", html("Tom &amp; Jerry"))
        assertEquals("&lt;<b>ta</b>g&gt;", html("&lt;tag&gt;"))
        assertEquals("<b>i</b>t&#x27;<b>s</b> &#39; &nbsp;<b>x</b>", html("it&#x27;s &#39; &nbsp;x"))
        assertEquals("&#X27; &#XAB;", html("&#X27; &#XAB;"))
        assertEquals("&frac12; &sup2;", html("&frac12; &sup2;"))
    }

    @Test
    fun `references act as word boundaries`() {
        assertEquals("<b>To</b>m&amp;<b>Jer</b>ry", html("Tom&amp;Jerry"))
        // The saccade counter still advances across the reference.
        assertEquals(
            "<b>on</b>e&amp;two <b>thr</b>ee",
            SmoothReading.toHtml("one&amp;two three", HtmlOptions(SmoothOptions(saccade = 2))),
        )
        assertEquals("<b>do</b>n&#39;<b>t</b>", html("don&#39;t"))
    }

    @Test
    fun `a bare ampersand is escaped`() {
        assertEquals("<b>To</b>m &amp; <b>Jer</b>ry", html("Tom & Jerry"))
        assertEquals("<b>a</b> &amp;<b>b</b> <b>c</b>", html("a &b c")) // no `;` → not a reference
        assertEquals("<b>a</b> &amp;; <b>b</b>", html("a &; b"))
        assertEquals("<b>a</b> &amp;#; &amp;#<b>x</b>; <b>b</b>", html("a &#; &#x; b")) // `x` is just a word
        assertEquals("&amp;1; &amp;-<b>a</b>; &amp;", html("&1; &-a; &"))
        assertEquals("&amp;<b>am</b>p", html("&amp"))
        assertEquals("&amp;", html("&"))
        assertEquals("&amp;&amp;", html("&&amp;"))
    }

    @Test
    fun `every ampersand is escaped when tags are not ignored`() {
        assertEquals("<b>To</b>m &amp;<b>am</b>p; <b>Jer</b>ry", html("Tom &amp; Jerry", ignoreHtmlTags = false))
        assertEquals("&amp;#39;", html("&#39;", ignoreHtmlTags = false))
        assertEquals("&lt;<b>p</b>&gt;<b>h</b>i&lt;/<b>p</b>&gt;", html("<p>hi</p>", ignoreHtmlTags = false))
    }

    @Test
    fun `references inside skipped elements are verbatim`() {
        assertEquals("<code>a &amp; b &</code>", html("<code>a &amp; b &</code>"))
    }

    // --- What counts as a tag --------------------------------------------

    @Test
    fun `an angle bracket not followed by a markup start is text`() {
        assertEquals("<b>a</b> &lt; <b>b</b>", html("a < b"))
        assertEquals("1&lt;2", html("1<2"))
        assertEquals("<b>x</b> &lt;3 <b>y</b>", html("x <3 y"))
        assertEquals("<b>a</b> &lt; <b>b</b>&gt; <b>c</b>", html("a < b> c"))
        assertEquals("<b>a</b> &lt;-<b>b</b>&gt; <b>c</b>", html("a <-b> c"))
        assertEquals("&lt;", html("<"))
        assertEquals("&lt;<p><b>x</b></p>", html("<<p>x</p>"))
    }

    @Test
    fun `an angle bracket followed by a letter, slash, bang or question mark is markup`() {
        assertEquals("<p><b>h</b>i</p>", html("<p>hi</p>"))
        assertEquals("<!-- note --> <b>h</b>i", html("<!-- note --> hi"))
        assertEquals("<!-- a > b --> <b>h</b>i", html("<!-- a > b --> hi"))
        assertEquals("<!DOCTYPE html> <b>h</b>i", html("<!DOCTYPE html> hi"))
        assertEquals("<?xml version=\"1.0\"?> <b>h</b>i", html("<?xml version=\"1.0\"?> hi"))
        assertEquals("<br/><b>h</b>i<br />", html("<br/>hi<br />"))
    }

    @Test
    fun `an unclosed tag is text`() {
        assertEquals("<b>a</b> &lt;<b>p</b> <b>b</b>", html("a <p b"))
        assertEquals("<b>x</b> <b>th</b>en &lt;<b>p</b> <b>oo</b>ps", html("<b>x</b> then <p oops"))
        assertEquals("<b>a</b> &lt;!-- <b>b</b>", html("a <!-- b"))
    }

    @Test
    fun `tags with attributes are verbatim, ampersands included`() {
        assertEquals(
            "<a href=\"x?a=1&b=2\" title=\"a<b\"><b>g</b>o</a>",
            html("<a href=\"x?a=1&b=2\" title=\"a<b\">go</a>"),
        )
        // Like the TypeScript core, markup ends at the first `>`: a literal
        // `>` inside an attribute value ends the tag early.
        assertEquals("<i title=\"a><b>b</b>&quot;&gt;<b>g</b>o</i>", html("<i title=\"a>b\">go</i>"))
    }

    // --- skipTags ----------------------------------------------------------

    @Test
    fun `default skip tags`() {
        for (tag in HtmlOptions.DEFAULT_SKIP_TAGS) {
            assertEquals("<$tag>Smooth</$tag> <b>read</b>ing", html("<$tag>Smooth</$tag> reading"), tag)
        }
    }

    @Test
    fun `skip tags are case-insensitive`() {
        assertEquals("<CODE>Smooth</CODE> <b>read</b>ing", html("<CODE>Smooth</CODE> reading"))
        assertEquals(
            "<em>Smooth</em> <b>read</b>ing",
            SmoothReading.toHtml("<em>Smooth</em> reading", HtmlOptions(skipTags = listOf("EM"))),
        )
    }

    @Test
    fun `nested skip elements track depth`() {
        assertEquals("<pre>a <pre>b</pre> c</pre> <b>read</b>ing", html("<pre>a <pre>b</pre> c</pre> reading"))
        // A different skip tag inside a skipped element does not end the skip.
        assertEquals("<pre>a <code>b</code> c</pre> <b>read</b>ing", html("<pre>a <code>b</code> c</pre> reading"))
    }

    @Test
    fun `a self-closing skip tag does not start a skip`() {
        assertEquals("<code/> <b>read</b>ing", html("<code/> reading"))
    }

    @Test
    fun `an unclosed skip element skips to the end`() {
        assertEquals("<code>Smooth reading", html("<code>Smooth reading"))
    }

    @Test
    fun `overriding skip tags replaces the defaults`() {
        assertEquals(
            "<code><b>Smo</b>oth</code> <em>reading</em>",
            SmoothReading.toHtml("<code>Smooth</code> <em>reading</em>", HtmlOptions(skipTags = listOf("em"))),
        )
        assertEquals(
            "<code><b>Smo</b>oth</code>",
            SmoothReading.toHtml("<code>Smooth</code>", HtmlOptions(skipTags = emptyList())),
        )
    }

    @Test
    fun `saccade counting continues across skipped elements`() {
        // Words inside skipped elements are not tokenized and consume nothing:
        // one(0) three(1) four(2).
        assertEquals(
            "<b>on</b>e <code>two</code> three <b>fo</b>ur",
            SmoothReading.toHtml("one <code>two</code> three four", HtmlOptions(SmoothOptions(saccade = 2))),
        )
    }

    // --- Implicit tag / restTag skip ---------------------------------------

    @Test
    fun `the emphasis tag is implicitly skipped`() {
        assertEquals("<b>Smooth</b> <b>read</b>ing", html("<b>Smooth</b> reading"))
        assertEquals("<B>Smooth</B> <b>read</b>ing", html("<B>Smooth</B> reading"))
        assertEquals(
            "<strong>Smooth</strong> <strong>read</strong>ing",
            SmoothReading.toHtml("<strong>Smooth</strong> reading", HtmlOptions(tag = "strong")),
        )
        // The default `b` is *not* skipped once the tag is something else.
        assertEquals(
            "<b><strong>Smo</strong>oth</b> <strong>read</strong>ing",
            SmoothReading.toHtml("<b>Smooth</b> reading", HtmlOptions(tag = "strong")),
        )
    }

    @Test
    fun `the rest tag is implicitly skipped`() {
        val options = HtmlOptions(tag = "span", className = "sr-fixation", restTag = "i")
        assertEquals(
            "<span>Smo</span><i>oth</i> <span class=\"sr-fixation\">read</span><i>ing</i>",
            SmoothReading.toHtml("<span>Smo</span><i>oth</i> reading", options),
        )
    }

    @Test
    fun `re-rendering own output never nests emphasis`() {
        val options = HtmlOptions(tag = "span", className = "sr-fixation", restTag = "span", restClassName = "sr-rest")
        val once = SmoothReading.toHtml("Smooth reading works, don't stop.", options)
        // Everything is inside a skipped `span`, so the second pass is a no-op.
        assertEquals(once, SmoothReading.toHtml(once, options))
        val defaults = SmoothReading.toHtml("Smooth reading works.")
        assertFalse(SmoothReading.toHtml(defaults).contains("<b><b>"))
    }

    // --- restTag and words without a fixation ------------------------------

    @Test
    fun `words without a fixation are never wrapped in the rest tag`() {
        val options = HtmlOptions(SmoothOptions(fixation = 2, saccade = 2), restTag = "i", restClassName = "r")
        // `a` gets no fixation at strength 2; `2024` is a number; `two`/`four`
        // are skipped by the saccade. All of them are plain text. (`one` at
        // strength 2: floor((3 * 35 + 50) / 100) = 1.)
        assertEquals(
            "a 2024 <b>o</b><i class=\"r\">ne</i> two <b>th</b><i class=\"r\">ree</i> four",
            SmoothReading.toHtml("a 2024 one two three four", options),
        )
        assertEquals("2024", SmoothReading.toHtml("2024", HtmlOptions(restTag = "i")))
    }

    @Test
    fun `the rest tag is omitted when the whole word is the fixation`() {
        assertEquals("<b>a</b>", SmoothReading.toHtml("a", HtmlOptions(restTag = "i")))
        assertEquals("<b>to</b>", SmoothReading.toHtml("to", HtmlOptions(SmoothOptions(fixation = 5), restTag = "i")))
    }

    @Test
    fun `class names are escaped`() {
        assertEquals(
            "<b class=\"a&quot;b&amp;c\">t</b>o",
            SmoothReading.toHtml("to", HtmlOptions(className = "a\"b&c")),
        )
    }

    @Test
    fun `tag names are validated`() {
        assertThrows(IllegalArgumentException::class.java) { HtmlOptions(tag = "") }
        assertThrows(IllegalArgumentException::class.java) { HtmlOptions(tag = "b>") }
        assertThrows(IllegalArgumentException::class.java) { HtmlOptions(restTag = "1x") }
        HtmlOptions(tag = "sr-fix", restTag = "span")
    }
}
