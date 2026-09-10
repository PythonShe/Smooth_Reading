import XCTest

@testable import SmoothReading

final class HtmlTests: XCTestCase {

    func testSpecExample() {
        XCTAssertEqual(
            SmoothReading.html("Smooth reading works."),
            "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.")
    }

    func testApostropheAndHyphen() {
        XCTAssertEqual(SmoothReading.html("don't"), "<b>don</b>'t")
        // `known` is 5 graphemes: 5 * 0.5 = 2.5, rounded half up → 3.
        XCTAssertEqual(SmoothReading.html("well-known"), "<b>we</b>ll-<b>kno</b>wn")
    }

    func testStrength() {
        let text = "Smooth reading"
        XCTAssertEqual(
            SmoothReading.html(text, options: HtmlOptions(options: SmoothOptions(fixation: 1))),
            "<b>S</b>mooth <b>r</b>eading")
        XCTAssertEqual(
            SmoothReading.html(text, options: HtmlOptions(options: SmoothOptions(fixation: 5))),
            "<b>Smoot</b>h <b>readin</b>g")
    }

    func testSaccade() {
        XCTAssertEqual(
            SmoothReading.html("one two three four", options: HtmlOptions(options: SmoothOptions(saccade: 2))),
            "<b>on</b>e two <b>thr</b>ee four")
    }

    func testMinWordLength() {
        XCTAssertEqual(
            SmoothReading.html("a to the read", options: HtmlOptions(options: SmoothOptions(minWordLength: 4))),
            "a to the <b>re</b>ad")
    }

    /// SPEC §4 guarantee 2: out-of-range values are clamped, never rejected and
    /// never replaced by the default. The fixture harness feeds raw JSON values
    /// straight through, so these are exactly the values a fixture may carry.
    func testOutOfRangeOptionsAreClamped() {
        func html(_ text: String, _ options: SmoothOptions) -> String {
            SmoothReading.html(text, options: HtmlOptions(options: options))
        }
        XCTAssertEqual(html("hello", SmoothOptions(fixation: 99)), "<b>hell</b>o")  // == 5
        XCTAssertEqual(html("hello", SmoothOptions(fixation: 5)), "<b>hell</b>o")
        XCTAssertEqual(html("hello", SmoothOptions(fixation: 0)), "<b>h</b>ello")  // == 1
        XCTAssertEqual(html("hello", SmoothOptions(fixation: 1)), "<b>h</b>ello")
        XCTAssertEqual(html("hello world", SmoothOptions(saccade: 0)), "<b>hel</b>lo <b>wor</b>ld")  // == 1
        XCTAssertEqual(html("hello world", SmoothOptions(saccade: -3)), "<b>hel</b>lo <b>wor</b>ld")
        // `minWordLength` below zero suppresses nothing, exactly like `0`.
        XCTAssertEqual(html("hello a", SmoothOptions(minWordLength: -1)), "<b>hel</b>lo <b>a</b>")
        XCTAssertEqual(html("hello a", SmoothOptions(minWordLength: 0)), "<b>hel</b>lo <b>a</b>")
    }

    func testNumbers() {
        XCTAssertEqual(SmoothReading.html("2024 was fine"), "2024 <b>wa</b>s <b>fi</b>ne")
        XCTAssertEqual(
            SmoothReading.html("2024", options: HtmlOptions(options: SmoothOptions(emphasizeNumbers: true))),
            "<b>20</b>24")
    }

    func testEscaping() {
        XCTAssertEqual(
            SmoothReading.html("Tom & \"Jerry\""),
            "<b>To</b>m &amp; &quot;<b>Jer</b>ry&quot;")
    }

    func testExistingTagsArePassedThrough() {
        XCTAssertEqual(
            SmoothReading.html("<p class=\"x\">Smooth reading</p>"),
            "<p class=\"x\"><b>Smo</b>oth <b>read</b>ing</p>")
    }

    func testSkipTags() {
        XCTAssertEqual(
            SmoothReading.html("<code>Smooth</code> reading"),
            "<code>Smooth</code> <b>read</b>ing")
        XCTAssertEqual(
            SmoothReading.html("<pre><code>a b</code></pre> reading"),
            "<pre><code>a b</code></pre> <b>read</b>ing")
    }

    func testIgnoreHtmlTagsDisabledEscapesEverything() {
        XCTAssertEqual(
            SmoothReading.html("<p>hi</p>", options: HtmlOptions(ignoreHtmlTags: false)),
            "&lt;<b>p</b>&gt;<b>h</b>i&lt;/<b>p</b>&gt;")
    }

    func testCustomTagsAndClasses() {
        let options = HtmlOptions(
            tag: "span", className: "sr-fixation", restTag: "span", restClassName: "sr-rest")
        XCTAssertEqual(
            SmoothReading.html("to", options: options),
            "<span class=\"sr-fixation\">t</span><span class=\"sr-rest\">o</span>")
    }

    func testDeterministicOutput() {
        let input = "<p>Smooth reading works, don't stop.</p>"
        XCTAssertEqual(SmoothReading.html(input), SmoothReading.html(input))
    }

    /// Spec §4: already-emphasised HTML is never wrapped a second time — the
    /// fixation tag (and `restTag`) are implicitly skipped.
    func testAlreadyEmphasisedHtmlIsNotDoubleWrapped() {
        XCTAssertEqual(SmoothReading.html("<b>Smooth</b> reading"), "<b>Smooth</b> <b>read</b>ing")
        // Re-running over generated output never nests emphasis, though the
        // word remainders left outside the tag are their own text runs.
        let once = SmoothReading.html("Smooth reading works.")
        XCTAssertFalse(SmoothReading.html(once).contains("<b><b>"))
    }

    func testUnclosedAngleBracketIsTreatedAsText() {
        XCTAssertEqual(SmoothReading.html("a < b"), "<b>a</b> &lt; <b>b</b>")
    }

    func testEmptyInput() {
        XCTAssertEqual(SmoothReading.html(""), "")
    }
}
