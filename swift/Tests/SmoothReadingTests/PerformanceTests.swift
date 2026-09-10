import XCTest

@testable import SmoothReading

/// Sanity checks that the renderers stay linear on realistic inputs. The
/// bounds are deliberately generous (debug builds, CI machines); a quadratic
/// regression blows past them by orders of magnitude.
final class PerformanceTests: XCTestCase {

    /// ~100 kB of mixed prose, markup, entities and non-ASCII text.
    private static let largeInput: String = {
        let paragraph = """
            <p>Smooth reading works, doesn't it? Tom &amp; Jerry read 42 books in 2024 &#8212; \
            naïve, well-known, Привет мир, Καλημέρα κόσμε, 你好世界 &lt;3 > 2, <em>emphasis</em> \
            <code>toHtml(x)</code> and a bare & ampersand.</p>\n
            """
        var text = ""
        while text.utf8.count < 100_000 { text += paragraph }
        return text
    }()

    private static let bareBrackets: String = String(repeating: "a < b ", count: 20_000)

    private func assertFast(_ name: String, limit: TimeInterval = 5, _ body: () -> Void) {
        let start = Date()
        body()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, limit, "\(name) took \(elapsed)s")
    }

    func testHtmlOnALargeInputIsLinear() {
        let input = Self.largeInput
        XCTAssertGreaterThanOrEqual(input.utf8.count, 100_000)
        assertFast("html") { _ = SmoothReading.html(input) }
        assertFast("html (locale)") {
            _ = SmoothReading.html(input, options: HtmlOptions(options: SmoothOptions(locale: Locale(identifier: "en"))))
        }
        assertFast("html (ignoreHtmlTags: false)") {
            _ = SmoothReading.html(input, options: HtmlOptions(ignoreHtmlTags: false))
        }
    }

    func testManyBareAngleBracketsWithoutAClosingOneStayLinear() {
        assertFast("bare <") { _ = SmoothReading.html(Self.bareBrackets) }
    }

    func testTokenizeAndAttributedStringOnALargeInput() {
        let input = Self.largeInput
        assertFast("tokenize") { _ = SmoothReading.tokenize(input) }
        assertFast("attributedString") { _ = SmoothReading.attributedString(input) }
        #if canImport(UIKit) || canImport(AppKit)
        assertFast("nsAttributedString") { _ = SmoothReading.nsAttributedString(input) }
        #endif
    }
}
