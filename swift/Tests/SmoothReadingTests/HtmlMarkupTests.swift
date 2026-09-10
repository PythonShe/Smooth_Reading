import XCTest

@testable import SmoothReading

/// Spec §4 markup rules: character references, what counts as a tag, and the
/// `skipTags` semantics (including the implicit `tag` / `restTag` skip).
final class HtmlMarkupTests: XCTestCase {

    private func html(_ text: String, ignoreHtmlTags: Bool = true) -> String {
        SmoothReading.html(text, options: HtmlOptions(ignoreHtmlTags: ignoreHtmlTags))
    }

    // MARK: - Character references

    func testExistingReferencesPassThroughVerbatim() {
        XCTAssertEqual(html("Tom &amp; Jerry"), "<b>To</b>m &amp; <b>Jer</b>ry")
        XCTAssertEqual(html("&lt;tag&gt;"), "&lt;<b>ta</b>g&gt;")
        XCTAssertEqual(html("it&#x27;s &#39; &nbsp;x"), "<b>i</b>t&#x27;<b>s</b> &#39; &nbsp;<b>x</b>")
        XCTAssertEqual(html("&#X27; &#XAB;"), "&#X27; &#XAB;")
        XCTAssertEqual(html("&frac12; &sup2;"), "&frac12; &sup2;")
    }

    func testReferencesActAsWordBoundaries() {
        // `Tom&amp;Jerry` is two words; the saccade counter still advances.
        XCTAssertEqual(html("Tom&amp;Jerry"), "<b>To</b>m&amp;<b>Jer</b>ry")
        XCTAssertEqual(
            SmoothReading.html(
                "one&amp;two three", options: HtmlOptions(options: SmoothOptions(saccade: 2))),
            "<b>on</b>e&amp;two <b>thr</b>ee")
        // Words split by a reference are counted as separate words.
        XCTAssertEqual(html("don&#39;t"), "<b>do</b>n&#39;<b>t</b>")
    }

    func testBareAmpersandIsEscaped() {
        XCTAssertEqual(html("Tom & Jerry"), "<b>To</b>m &amp; <b>Jer</b>ry")
        XCTAssertEqual(html("a &b c"), "<b>a</b> &amp;<b>b</b> <b>c</b>")  // no `;` → not a reference
        XCTAssertEqual(html("a &; b"), "<b>a</b> &amp;; <b>b</b>")
        // Spec §4: a malformed reference such as `&#;` or `&#x;` is not a
        // reference — the `&` is escaped and the rest is ordinary text, so the
        // `x` is a word and gets its fixation.
        XCTAssertEqual(html("a &#; &#x; b"), "<b>a</b> &amp;#; &amp;#<b>x</b>; <b>b</b>")
        XCTAssertEqual(html("&1; &-a; &"), "&amp;1; &amp;-<b>a</b>; &amp;")
        XCTAssertEqual(html("&amp"), "&amp;<b>am</b>p")
        XCTAssertEqual(html("&"), "&amp;")
        XCTAssertEqual(html("&&amp;"), "&amp;&amp;")
    }

    func testEveryAmpersandIsEscapedWhenTagsAreNotIgnored() {
        XCTAssertEqual(html("Tom &amp; Jerry", ignoreHtmlTags: false), "<b>To</b>m &amp;<b>am</b>p; <b>Jer</b>ry")
        XCTAssertEqual(html("&#39;", ignoreHtmlTags: false), "&amp;#39;")
    }

    func testReferencesInsideSkippedElementsAreVerbatim() {
        XCTAssertEqual(html("<code>a &amp; b &</code>"), "<code>a &amp; b &</code>")
    }

    // MARK: - What counts as a tag

    func testAngleBracketNotFollowedByMarkupStartIsText() {
        XCTAssertEqual(html("a < b"), "<b>a</b> &lt; <b>b</b>")
        XCTAssertEqual(html("1<2"), "1&lt;2")
        XCTAssertEqual(html("x <3 y"), "<b>x</b> &lt;3 <b>y</b>")
        XCTAssertEqual(html("a < b> c"), "<b>a</b> &lt; <b>b</b>&gt; <b>c</b>")
        XCTAssertEqual(html("a <-b> c"), "<b>a</b> &lt;-<b>b</b>&gt; <b>c</b>")
        XCTAssertEqual(html("<"), "&lt;")
        XCTAssertEqual(html("<<p>x</p>"), "&lt;<p><b>x</b></p>")
    }

    func testAngleBracketFollowedByLetterSlashBangOrQuestionIsMarkup() {
        XCTAssertEqual(html("<p>hi</p>"), "<p><b>h</b>i</p>")
        XCTAssertEqual(html("<!-- note --> hi"), "<!-- note --> <b>h</b>i")
        XCTAssertEqual(html("<!DOCTYPE html> hi"), "<!DOCTYPE html> <b>h</b>i")
        XCTAssertEqual(html("<?xml version=\"1.0\"?> hi"), "<?xml version=\"1.0\"?> <b>h</b>i")
        XCTAssertEqual(html("<br/>hi<br />"), "<br/><b>h</b>i<br />")
    }

    func testUnclosedTagIsText() {
        XCTAssertEqual(html("a <p b"), "<b>a</b> &lt;<b>p</b> <b>b</b>")
        XCTAssertEqual(html("<b>x</b> then <p oops"), "<b>x</b> <b>th</b>en &lt;<b>p</b> <b>oo</b>ps")
    }

    func testTagsWithAttributesAreVerbatim() {
        // Attribute values are not escaped or re-tokenized; a `<` inside one is
        // fine.
        XCTAssertEqual(
            html("<a href=\"x?a=1&b=2\" title=\"<\">go</a>"),
            "<a href=\"x?a=1&b=2\" title=\"<\"><b>g</b>o</a>")
        // Spec §4: a tag ends at the **first** `>`; quoted attribute values are
        // not parsed. So `title="<>"` closes the tag after `<>` and the rest
        // (`">`) is text, exactly as in the reference lexer.
        XCTAssertEqual(
            html("<a href=\"x?a=1&b=2\" title=\"<>\">go</a>"),
            "<a href=\"x?a=1&b=2\" title=\"<>&quot;&gt;<b>g</b>o</a>")
    }

    func testCommentsAndCDataEndAtTheirOwnTerminator() {
        // Spec §4: a comment ends at the first `-->` and a CDATA section at
        // `]]>`; both may contain `>`.
        XCTAssertEqual(html("<!-- a > b --> c"), "<!-- a > b --> <b>c</b>")
        XCTAssertEqual(html("<![CDATA[ a > b ]]> c"), "<![CDATA[ a > b ]]> <b>c</b>")
        XCTAssertEqual(html("<!--code-->x"), "<!--code--><b>x</b>")
        XCTAssertEqual(html("<!---->x"), "<!----><b>x</b>")
        // The terminator is searched after the opener, so `<!-->` is not a
        // complete comment; it degrades to a `<!...>` declaration.
        XCTAssertEqual(html("<!-->x"), "<!--><b>x</b>")
        // A closing tag inside a comment does not end a skipped element.
        XCTAssertEqual(html("<code><!-- </code> --> x</code> y"), "<code><!-- </code> --> x</code> <b>y</b>")
    }

    func testUnterminatedCommentOrCDataDegradesToADeclaration() {
        // Without `-->` / `]]>` the block is an ordinary `<!...>` ending at the
        // first `>`, matching `findTagEnd` in the reference lexer.
        XCTAssertEqual(html("<!-- a > b"), "<!-- a > <b>b</b>")
        XCTAssertEqual(html("<![CDATA[ a > b"), "<![CDATA[ a > <b>b</b>")
        XCTAssertEqual(html("<!-- a b"), "&lt;!-- <b>a</b> <b>b</b>")
    }

    // MARK: - skipTags

    func testDefaultSkipTags() {
        for tag in HtmlOptions.defaultSkipTags {
            XCTAssertEqual(html("<\(tag)>Smooth</\(tag)> reading"), "<\(tag)>Smooth</\(tag)> <b>read</b>ing", tag)
        }
    }

    func testSkipTagsAreCaseInsensitive() {
        XCTAssertEqual(html("<CODE>Smooth</CODE> reading"), "<CODE>Smooth</CODE> <b>read</b>ing")
        XCTAssertEqual(
            SmoothReading.html("<em>Smooth</em> reading", options: HtmlOptions(skipTags: ["EM"])),
            "<em>Smooth</em> <b>read</b>ing")
    }

    func testNestedSkipElementsTrackDepth() {
        XCTAssertEqual(
            html("<pre>a <pre>b</pre> c</pre> reading"),
            "<pre>a <pre>b</pre> c</pre> <b>read</b>ing")
        // A different skip tag inside a skipped element does not end the skip.
        XCTAssertEqual(
            html("<pre>a <code>b</code> c</pre> reading"),
            "<pre>a <code>b</code> c</pre> <b>read</b>ing")
    }

    func testSelfClosingSkipTagDoesNotStartASkip() {
        XCTAssertEqual(html("<code/> reading"), "<code/> <b>read</b>ing")
    }

    func testUnclosedSkipElementSkipsToTheEnd() {
        XCTAssertEqual(html("<code>Smooth reading"), "<code>Smooth reading")
    }

    func testOverridingSkipTagsReplacesTheDefaults() {
        let options = HtmlOptions(skipTags: ["em"])
        XCTAssertEqual(
            SmoothReading.html("<code>Smooth</code> <em>reading</em>", options: options),
            "<code><b>Smo</b>oth</code> <em>reading</em>")
        XCTAssertEqual(
            SmoothReading.html("<code>Smooth</code>", options: HtmlOptions(skipTags: [])),
            "<code><b>Smo</b>oth</code>")
    }

    func testSaccadeCountingContinuesAcrossSkippedElements() {
        // Spec §4: "Text inside `skipTags` is never tokenised and consumes
        // nothing." `two` takes no saccade index, so the counter goes one=0,
        // three=1, four=2 and `four` is the second emphasised word.
        XCTAssertEqual(
            SmoothReading.html(
                "one <code>two</code> three four", options: HtmlOptions(options: SmoothOptions(saccade: 2))),
            "<b>on</b>e <code>two</code> three <b>fo</b>ur")
    }

    // MARK: - Implicit tag / restTag skip

    func testEmphasisTagIsImplicitlySkipped() {
        XCTAssertEqual(html("<b>Smooth</b> reading"), "<b>Smooth</b> <b>read</b>ing")
        XCTAssertEqual(html("<B>Smooth</B> reading"), "<B>Smooth</B> <b>read</b>ing")
        XCTAssertEqual(
            SmoothReading.html("<strong>Smooth</strong> reading", options: HtmlOptions(tag: "strong")),
            "<strong>Smooth</strong> <strong>read</strong>ing")
        // The default `b` is *not* skipped once the tag is something else.
        XCTAssertEqual(
            SmoothReading.html("<b>Smooth</b> reading", options: HtmlOptions(tag: "strong")),
            "<b><strong>Smo</strong>oth</b> <strong>read</strong>ing")
    }

    func testRestTagIsImplicitlySkipped() {
        let options = HtmlOptions(tag: "span", className: "sr-fixation", restTag: "i")
        XCTAssertEqual(
            SmoothReading.html("<span>Smo</span><i>oth</i> reading", options: options),
            "<span>Smo</span><i>oth</i> <span class=\"sr-fixation\">read</span><i>ing</i>")
    }

    func testRerenderingOwnOutputNeverNestsEmphasis() {
        let options = HtmlOptions(tag: "span", className: "sr-fixation", restTag: "span", restClassName: "sr-rest")
        let once = SmoothReading.html("Smooth reading works, don't stop.", options: options)
        let twice = SmoothReading.html(once, options: options)
        // Everything is inside a skipped `span`, so the second pass is a no-op.
        XCTAssertEqual(twice, once)
        let defaults = SmoothReading.html("Smooth reading works.")
        XCTAssertFalse(SmoothReading.html(defaults).contains("<b><b>"))
    }

    // MARK: - restTag and words without a fixation

    func testWordsWithoutAFixationAreNeverWrappedInRestTag() {
        let options = HtmlOptions(options: SmoothOptions(fixation: 2, saccade: 2), restTag: "i", restClassName: "r")
        // `a` gets no fixation at strength 2; `2024` is a number; `two`/`four`
        // are skipped by the saccade. All of them are plain text. `one` (n=3)
        // at strength 2 uses the spec §2 integer formula
        // `floor((3*35+50)/100) = 1`, so only `o` is emphasised.
        XCTAssertEqual(
            SmoothReading.html("a 2024 one two three four", options: options),
            "a 2024 <b>o</b><i class=\"r\">ne</i> two <b>th</b><i class=\"r\">ree</i> four")
        XCTAssertEqual(
            SmoothReading.html("2024", options: HtmlOptions(options: SmoothOptions(emphasizeNumbers: false), restTag: "i")),
            "2024")
    }

    func testRestTagIsOmittedWhenTheWholeWordIsTheFixation() {
        XCTAssertEqual(SmoothReading.html("a", options: HtmlOptions(restTag: "i")), "<b>a</b>")
        XCTAssertEqual(
            SmoothReading.html("to", options: HtmlOptions(options: SmoothOptions(fixation: 5), restTag: "i")),
            "<b>to</b>")
    }

    func testClassNamesAreEscaped() {
        XCTAssertEqual(
            SmoothReading.html("to", options: HtmlOptions(className: "a\"b&c")),
            "<b class=\"a&quot;b&amp;c\">t</b>o")
    }
}
