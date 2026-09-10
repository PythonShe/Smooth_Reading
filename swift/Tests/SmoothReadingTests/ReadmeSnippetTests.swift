import XCTest

import SmoothReading

#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Every code block in `README.md` lives here verbatim (modulo the `import`
/// lines), so the README can never drift from the API. The UIKit and AppKit
/// blocks compile on their respective platforms; the platform-neutral ones run.
final class ReadmeSnippetTests: XCTestCase {

    // MARK: README "UIKit"

    #if canImport(UIKit) && !os(watchOS)
    @MainActor
    func readmeUIKit() {
        let article = "Smooth reading works."

        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.attributedText = SmoothReading.nsAttributedString(
            article,
            options: SmoothOptions(fixation: 3),
            font: label.font
        )

        // Or the one-line convenience, which reuses the view's current font:
        label.applySmoothReading(article)

        let textView = UITextView()
        textView.applySmoothReading(article, options: SmoothOptions(fixation: 4, saccade: 2))
    }

    @MainActor
    func readmeUIKitCustomEmphasis() {
        let label = UILabel()
        label.attributedText = SmoothReading.nsAttributedString(
            "Smooth reading works.",
            font: label.font,
            fixationAttributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.label,
            ],
            restAttributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
            ]
        )
    }
    #endif

    // MARK: README "AppKit"

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    func readmeAppKit() {
        let article = "Smooth reading works."

        let field = NSTextField(labelWithString: "")
        field.attributedStringValue = SmoothReading.nsAttributedString(article, font: field.font)

        // Convenience setters on NSTextField and NSTextView:
        field.applySmoothReading(article)

        let textView = NSTextView()
        textView.applySmoothReading(article, options: SmoothOptions(fixation: 4))
    }
    #endif

    // MARK: README "SwiftUI"

    #if canImport(SwiftUI)
    struct ArticleView: View {
        let article: String

        var body: some View {
            Text(SmoothReading.attributedString(article, options: SmoothOptions(fixation: 3)))
                .font(.body)
        }
    }

    struct TintedArticleView: View {
        let article: String

        var body: some View {
            var fixation = AttributeContainer()
            fixation.foregroundColor = .accentColor
            fixation.inlinePresentationIntent = .stronglyEmphasized

            var rest = AttributeContainer()
            rest.foregroundColor = .secondary

            return Text(
                SmoothReading.attributedString(article, fixationAttributes: fixation, restAttributes: rest)
            )
        }
    }

    @MainActor
    func testSwiftUIViewsBuild() {
        _ = ArticleView(article: "Smooth reading works.").body
        _ = TintedArticleView(article: "Smooth reading works.").body
    }
    #endif

    // MARK: README "HTML and tokens"

    func testHtmlAndTokens() {
        XCTAssertEqual(
            SmoothReading.html("Smooth reading works."),
            "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.")

        XCTAssertEqual(
            SmoothReading.html(
                "Smooth reading",
                options: HtmlOptions(
                    options: SmoothOptions(fixation: 4),
                    tag: "span", className: "sr-fixation",
                    restTag: "span", restClassName: "sr-rest"
                )
            ),
            "<span class=\"sr-fixation\">Smoo</span><span class=\"sr-rest\">th</span> "
                + "<span class=\"sr-fixation\">readi</span><span class=\"sr-rest\">ng</span>")

        // Existing markup and character references pass through untouched:
        XCTAssertEqual(
            SmoothReading.html("<p>Tom &amp; <code>Jerry</code></p>"),
            "<p><b>To</b>m &amp; <code>Jerry</code></p>")

        var lines: [String] = []
        for token in SmoothReading.tokenize("Smooth reading") {
            switch token {
            case let .word(text, fixation, fixationText, restText):
                lines.append("\(text) \(fixation) \(fixationText) \(restText)")
            case let .separator(text):
                lines.append("sep \(text)")
            }
        }
        XCTAssertEqual(lines, ["Smooth 3 Smo oth", "sep  ", "reading 4 read ing"])
    }

    // MARK: README "Options" table

    func testOptionsTableClaims() {
        // Values outside 1...5 are clamped; saccade below 1 is clamped.
        XCTAssertEqual(SmoothReading.html("reading", options: HtmlOptions(options: SmoothOptions(fixation: 9))), "<b>readin</b>g")
        XCTAssertEqual(SmoothReading.html("one two", options: HtmlOptions(options: SmoothOptions(saccade: 0))), "<b>on</b>e <b>tw</b>o")
        let custom = SmoothOptions(fixationLength: { _, graphemes, _ in graphemes })
        XCTAssertEqual(SmoothReading.html("reading", options: HtmlOptions(options: custom)), "<b>reading</b>")
    }
}
