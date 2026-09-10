import XCTest

@testable import SmoothReading

/// Multilingual and bidi guarantees over every fixture input (`docs/LANGUAGES.md`).
///
/// Beyond matching the expected HTML (see `FixtureTests`), every input — from
/// `common` and `segmenter` alike — must satisfy three invariants: tokens and
/// attributed strings are lossless, the markup adds nothing but emphasis tags,
/// and no direction-changing attribute or bidi control character is introduced.
final class LanguagesTests: XCTestCase {

    private struct Options: Decodable {
        var fixation: Int?
        var saccade: Int?
        var minWordLength: Int?
        var emphasizeNumbers: Bool?
        var locale: String?
        var tag: String?
        var className: String?
        var restTag: String?
        var restClassName: String?
        var ignoreHtmlTags: Bool?
        var skipTags: [String]?
    }

    private struct Case: Decodable {
        var name: String
        var input: String
        var options: Options?
        var html: String
    }

    private static let fixturesRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // SmoothReadingTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // swift
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("fixtures")

    /// Every case of both suites, labelled `suite/file: name`.
    private static func allCases() throws -> [(label: String, fixture: Case)] {
        var out: [(String, Case)] = []
        for suite in ["common", "segmenter"] {
            let directory = fixturesRoot.appendingPathComponent(suite)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for file in files {
                for fixture in try JSONDecoder().decode([Case].self, from: Data(contentsOf: file)) {
                    out.append(("\(suite)/\(file.lastPathComponent): \(fixture.name)", fixture))
                }
            }
        }
        XCTAssertGreaterThan(out.count, 100, "expected the scripts, cjk-extended and bidi fixtures to be present")
        return out
    }

    private static func smoothOptions(_ json: Options?) -> SmoothOptions {
        var options = SmoothOptions()
        guard let json else { return options }
        if let value = json.fixation { options.fixation = value }
        if let value = json.saccade { options.saccade = value }
        if let value = json.minWordLength { options.minWordLength = value }
        if let value = json.emphasizeNumbers { options.emphasizeNumbers = value }
        if let value = json.locale { options.locale = Locale(identifier: value) }
        return options
    }

    private static func htmlOptions(_ json: Options?, options: SmoothOptions) -> HtmlOptions {
        var html = HtmlOptions()
        html.options = options
        guard let json else { return html }
        if let value = json.tag { html.tag = value }
        if let value = json.className { html.className = value }
        if let value = json.restTag { html.restTag = value }
        if let value = json.restClassName { html.restClassName = value }
        if let value = json.ignoreHtmlTags { html.ignoreHtmlTags = value }
        if let value = json.skipTags { html.skipTags = Set(value) }
        return html
    }

    // LRM, RLM, ALM, the explicit embeddings/overrides and the isolates.
    private static let bidiControls: Set<Unicode.Scalar> = {
        var set = Set<Unicode.Scalar>()
        for value in [0x200E, 0x200F, 0x061C] + Array(0x202A...0x202E) + Array(0x2066...0x2069) {
            set.insert(Unicode.Scalar(value)!)
        }
        return set
    }()

    private static func bidiControlCount(_ text: String) -> Int {
        text.unicodeScalars.filter { bidiControls.contains($0) }.count
    }

    private static func stripEmphasis(_ markup: String, tags: [String]) -> String {
        let names = tags.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return markup.replacingOccurrences(
            of: "</?(?:\(names))(?:\\s[^>]*)?>", with: "", options: .regularExpression)
    }

    private static func escape(_ text: String) -> String {
        SmoothReading.escapeHtml(text)
    }

    // MARK: - Invariants over every fixture input

    func testTokensAreLossless() throws {
        for (label, fixture) in try Self.allCases() {
            let tokens = SmoothReading.tokenize(fixture.input, options: Self.smoothOptions(fixture.options))
            XCTAssertEqual(tokens.map(\.text).joined(), fixture.input, label)
            for case let .word(text, _, fixationText, restText) in tokens {
                XCTAssertEqual(fixationText + restText, text, label)
            }
        }
    }

    func testAttributedStringsPreserveTheInputAndInsertNoIsolates() throws {
        for (label, fixture) in try Self.allCases() {
            let options = Self.smoothOptions(fixture.options)
            let runs = SmoothReading.runs(fixture.input, options: options)
            XCTAssertEqual(runs.map(\.text).joined(), fixture.input, label)
            let attributed = SmoothReading.attributedString(fixture.input, options: options)
            XCTAssertEqual(String(attributed.characters), fixture.input, label)
            XCTAssertEqual(Self.bidiControlCount(String(attributed.characters)),
                           Self.bidiControlCount(fixture.input), label)
            #if canImport(UIKit) || canImport(AppKit)
            let nsAttributed = SmoothReading.nsAttributedString(fixture.input, options: options)
            XCTAssertEqual(nsAttributed.string, fixture.input, label)
            #endif
        }
    }

    func testMarkupAddsNothingButEmphasisTags() throws {
        for (label, fixture) in try Self.allCases() {
            var options = Self.smoothOptions(fixture.options)
            let html = Self.htmlOptions(fixture.options, options: options)
            let rendered = SmoothReading.html(fixture.input, options: html)

            // The same render with every fixation suppressed adds no emphasis
            // tags of its own (the input may already contain some, hence
            // stripping both sides).
            options.fixationLength = { _, _, _ in 0 }
            var plainOptions = html
            plainOptions.options = options
            let plain = SmoothReading.html(fixture.input, options: plainOptions)

            var emphasis = [html.tag]
            if let restTag = html.restTag { emphasis.append(restTag) }
            XCTAssertEqual(Self.stripEmphasis(rendered, tags: emphasis),
                           Self.stripEmphasis(plain, tags: emphasis), label)
            if !html.ignoreHtmlTags || !fixture.input.contains(where: { $0 == "<" || $0 == "&" }) {
                XCTAssertEqual(plain, Self.escape(fixture.input), label)
            }
        }
    }

    func testNoDirAttributeOrBidiControlIsAdded() throws {
        for (label, fixture) in try Self.allCases() {
            let options = Self.smoothOptions(fixture.options)
            let rendered = SmoothReading.html(fixture.input, options: Self.htmlOptions(fixture.options, options: options))
            XCTAssertEqual(rendered.components(separatedBy: "dir=").count,
                           fixture.input.components(separatedBy: "dir=").count, label)
            XCTAssertEqual(Self.bidiControlCount(rendered), Self.bidiControlCount(fixture.input), label)
        }
    }

    // MARK: - Tokenizer details the fixtures rely on

    /// The ICU word breaker reports the space between a Latin brand name and
    /// digits inside Chinese text as a "word"; it must be a separator.
    func testSeparatorsReportedByTheWordEnumeratorAreNotWords() {
        XCTAssertEqual(
            SmoothReading.html("我用iPhone 15看视频"),
            "<b>我</b><b>用</b><b>iPh</b>one 15<b>看</b><b>视</b>频")
        XCTAssertEqual(
            SmoothReading.html("我们用iPhone 15拍照"),
            "<b>我</b>们<b>用</b><b>iPh</b>one 15<b>拍</b>照")
        for case let .word(text, _, _, _) in SmoothReading.tokenize("我用iPhone 15看视频") {
            XCTAssertFalse(text.allSatisfy(\.isWhitespace), "whitespace token \(text.debugDescription) is not a word")
        }
    }

    /// ICU reports UTF-16 offsets and splits `我́` (U+6211 U+0301) into the token
    /// `我` plus a token for the combining mark. SPEC §3 works in grapheme
    /// clusters, so the word must come back out whole — never dropped, never
    /// split between the base and its mark.
    func testTokenRangesAreWidenedToGraphemeClusters() {
        XCTAssertEqual(SmoothReading.html("我́x"), "<b>我́</b><b>x</b>")
        XCTAssertEqual(SmoothReading.tokenize("我́x").map(\.text).joined(), "我́x")
        let words = SmoothReading.tokenize("我́x").compactMap { token -> String? in
            if case let .word(text, _, _, _) = token { return text }
            return nil
        }
        XCTAssertEqual(words, ["我́", "x"])
        // Emoji sequences stay separators: a variation selector or ZWJ never
        // turns a symbol cluster into a word.
        XCTAssertEqual(SmoothReading.html("hello ❤️ world"), "<b>hel</b>lo ❤️ <b>wor</b>ld")
        XCTAssertEqual(SmoothReading.html("🇯🇵 flag"), "🇯🇵 <b>fl</b>ag")
        // A keycap is one grapheme cluster starting with a digit, so it is a
        // one-character word. It is not "entirely digits" (the variation
        // selector and U+20E3 are not `\p{Nd}`), so §2 rule 1 does not suppress
        // it — the same as the reference implementation.
        XCTAssertEqual(SmoothReading.html("1️⃣ x"), "<b>1️⃣</b> <b>x</b>")
    }

    func testDecomposedHangulJamoAndIndicConjunctsAreSingleClusters() {
        let decomposed = "한글".decomposedStringWithCanonicalMapping
        XCTAssertEqual(SmoothReading.html(decomposed, options: HtmlOptions(options: SmoothOptions(fixation: 1))),
                       "<b>\("한".decomposedStringWithCanonicalMapping)</b>\("글".decomposedStringWithCanonicalMapping)")
        XCTAssertEqual(SmoothReading.html("क्षत्रिय"), "<b>क्षत्रि</b>य")
        XCTAssertEqual(SmoothReading.html("उम्र"), "<b>उ</b>म्र")
        XCTAssertEqual(SmoothReading.html("தமிழ்"), "<b>தமி</b>ழ்")
    }
}
