import XCTest

@testable import SmoothReading

final class TokenizerTests: XCTestCase {

    private func words(_ text: String, _ options: SmoothOptions = .default) -> [String] {
        SmoothReading.tokenize(text, options: options).compactMap {
            if case let .word(word, _, _, _) = $0 { return word }
            return nil
        }
    }

    func testApostropheJoinsHyphenSplits() {
        XCTAssertEqual(words("don't"), ["don't"])
        XCTAssertEqual(words("it’s"), ["it’s"])  // typographic apostrophe
        XCTAssertEqual(words("well-known"), ["well", "known"])
    }

    func testTokensRebuildTheInput() {
        for input in ["Smooth reading works.", "Hello, world — don't stop!", "  spaced  out  ", ""] {
            let rebuilt = SmoothReading.tokenize(input).map(\.text).joined()
            XCTAssertEqual(rebuilt, input)
        }
    }

    func testWordSplit() {
        XCTAssertEqual(
            SmoothReading.tokenize("don't stop"),
            [
                .word(text: "don't", fixation: 3, fixationText: "don", restText: "'t"),
                .separator(text: " "),
                .word(text: "stop", fixation: 2, fixationText: "st", restText: "op"),
            ])
    }

    func testSaccadeCountsWordsOnly() {
        let tokens = SmoothReading.tokenize("one two three four", options: SmoothOptions(saccade: 2))
        let emphasised = tokens.compactMap { token -> String? in
            if case let .word(word, fixation, _, _) = token, fixation > 0 { return word }
            return nil
        }
        XCTAssertEqual(emphasised, ["one", "three"])
    }

    func testNumbersStillCountTowardsSaccade() {
        let tokens = SmoothReading.tokenize("2024 was fine", options: SmoothOptions(saccade: 2))
        let emphasised = tokens.compactMap { token -> String? in
            if case let .word(word, fixation, _, _) = token, fixation > 0 { return word }
            return nil
        }
        XCTAssertEqual(emphasised, ["fine"])
    }

    func testLocaleAwarePathAgreesForLatinText() {
        let localized = SmoothOptions(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(words("don't stop, well-known.", localized), ["don't", "stop", "well", "known"])
    }

    /// Dictionary-based CJK breaking is the default, not something a caller has
    /// to opt into with a locale: `nil` auto-detects the language rather than
    /// falling back to the root break rules, which split every Han character.
    func testCJKGetsDictionaryBreaksWithoutALocale() {
        XCTAssertEqual(words("你好，世界！"), ["你好", "世界"])
        XCTAssertEqual(words("我喜欢阅读"), ["我", "喜欢", "阅读"])
        XCTAssertEqual(words("日本語OKです"), ["日本", "語", "OK", "です"])
        XCTAssertEqual(words("こんにちは世界"), ["こんにちは", "世界"])
        XCTAssertEqual(words("สวัสดีชาวโลก").count, 2)
    }

    /// The same inputs through ``SmoothReading/html(_:options:)``, which is what
    /// the fixtures assert.
    func testCJKHtmlWithoutALocaleMatchesTheLocaleAwareOutput() {
        for (input, locale) in [
            ("你好，世界！", "zh"), ("我喜欢阅读", "zh"), ("日本語OKです", "ja"),
            ("こんにちは世界", "ja"), ("สวัสดีชาวโลก", "th"), ("私は本を読みます", "ja"),
        ] {
            let localized = HtmlOptions(options: SmoothOptions(locale: Locale(identifier: locale)))
            XCTAssertEqual(SmoothReading.html(input), SmoothReading.html(input, options: localized), input)
        }
        XCTAssertEqual(SmoothReading.html("你好，世界！"), "<b>你</b>好，<b>世</b>界！")
        XCTAssertEqual(SmoothReading.html("我喜欢阅读"), "<b>我</b><b>喜</b>欢<b>阅</b>读")
    }

    /// Auto-detection keeps only the language subtag, so the inherited script of
    /// a *guessed* language never changes the dictionary: text a caller wants
    /// segmented with the Traditional Chinese dictionary must say so explicitly.
    func testAnExplicitLocaleIsNeverOverriddenByDetection() {
        let hant = HtmlOptions(options: SmoothOptions(locale: Locale(identifier: "zh-Hant")))
        XCTAssertEqual(
            SmoothReading.html("我們今天學習中文。", options: hant),
            "<b>我</b>們<b>今</b>天<b>學</b>習<b>中</b>文。")
    }

    /// Without a locale, every `fixtures/segmenter` case whose locale is a plain
    /// language tag must still produce the fixture's HTML — the whole point of
    /// auto-detection. Cases pinned to a script (`zh-Hant`) are excluded: they
    /// exist to assert that an explicit variant wins.
    func testSegmenterFixturesAlsoPassWithNoLocaleAtAll() throws {
        var checked = 0
        for fixture in try Self.segmenterFixtures() {
            guard let locale = fixture.options?.locale, !locale.contains("-"), !locale.contains("_")
            else { continue }
            var options = SmoothOptions()
            if let value = fixture.options?.fixation { options.fixation = value }
            if let value = fixture.options?.saccade { options.saccade = value }
            if let value = fixture.options?.minWordLength { options.minWordLength = value }
            if let value = fixture.options?.emphasizeNumbers { options.emphasizeNumbers = value }
            XCTAssertEqual(
                SmoothReading.html(fixture.input, options: HtmlOptions(options: options)),
                fixture.html, "no locale: \(fixture.name)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
    }

    func testCJKIsSegmentedAndFullyPreserved() {
        // ICU applies dictionary-based breaks here; the exact segmentation is a
        // `fixtures/segmenter` concern, so only assert lossless round-tripping.
        let html = SmoothReading.html("你好世界，朋友")
        XCTAssertTrue(html.contains("<b>"))
        let stripped = html.replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
        XCTAssertEqual(stripped, "你好世界，朋友")
    }

    func testThaiIsSegmented() {
        XCTAssertEqual(words("สวัสดีครับ").count, 2)
    }

    /// The two locale paths — auto-detected and explicit — must produce
    /// identical word ranges for Latin-like text, including every
    /// `fixtures/common` input.
    func testBothTokenizerPathsAgree() throws {
        var inputs = [
            "Smooth reading works.", "don't stop, it’s well-known!", "...Hello, world!!!",
            "Привет мир", "Καλημέρα κόσμε", "nai\u{0308}ve reading", "hello 👋 world",
            "Read 42 books in 2024.", "  \n\t ", "", "<p>Smooth <em>reading</em></p>",
            "Tom &amp; Jerry", "a e i o u", "مرحبا بالعالم",
        ]
        inputs += try Self.commonFixtureInputs()
        for input in inputs {
            let range = input.startIndex..<input.endIndex
            let plain = Tokenizer.wordRanges(in: input, range: range, locale: nil).map { input[$0] }
            let localized = Tokenizer.wordRanges(in: input, range: range, locale: Locale(identifier: "en_US"))
                .map { input[$0] }
            XCTAssertEqual(plain, localized, input.debugDescription)
        }
    }

    /// Sub-ranges (as the HTML renderer uses between tags) agree as well.
    func testBothTokenizerPathsAgreeOnSubranges() {
        let input = "<p>Smooth reading</p> don't-stop"
        let start = input.index(input.startIndex, offsetBy: 3)
        let end = input.index(input.startIndex, offsetBy: 17)
        let plain = Tokenizer.wordRanges(in: input, range: start..<end, locale: nil).map { input[$0] }
        let localized = Tokenizer.wordRanges(in: input, range: start..<end, locale: Locale(identifier: "en"))
            .map { input[$0] }
        XCTAssertEqual(plain, ["Smooth", "reading"])
        XCTAssertEqual(plain, localized)
    }

    private struct FixtureInput: Decodable { var input: String }

    private struct SegmenterFixture: Decodable {
        struct Options: Decodable {
            var fixation: Int?
            var saccade: Int?
            var minWordLength: Int?
            var emphasizeNumbers: Bool?
            var locale: String?
        }
        var name: String
        var input: String
        var options: Options?
        var html: String
    }

    private static func fixtureFiles(_ suite: String) throws -> [URL] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("fixtures/\(suite)")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty)
        return files
    }

    private static func commonFixtureInputs() throws -> [String] {
        try fixtureFiles("common")
            .flatMap { try JSONDecoder().decode([FixtureInput].self, from: Data(contentsOf: $0)) }
            .map(\.input)
    }

    private static func segmenterFixtures() throws -> [SegmenterFixture] {
        try fixtureFiles("segmenter")
            .flatMap { try JSONDecoder().decode([SegmenterFixture].self, from: Data(contentsOf: $0)) }
    }
}
