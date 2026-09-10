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

    /// The two ICU paths — `enumerateSubstrings(.byWords)` without a locale and
    /// `CFStringTokenizer` with one — must produce identical word ranges for
    /// Latin-like text, including every `fixtures/common` input.
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

    private static func commonFixtureInputs() throws -> [String] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("fixtures/common")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertFalse(files.isEmpty)
        return try files.flatMap { try JSONDecoder().decode([FixtureInput].self, from: Data(contentsOf: $0)) }
            .map(\.input)
    }
}
