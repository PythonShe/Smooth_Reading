import XCTest

@testable import SmoothReading

/// Hand-derived from the tables in `docs/SPEC.md` §2.
final class FixationLengthTests: XCTestCase {

    private func length(_ word: String, _ options: SmoothOptions = .default) -> Int {
        SmoothReading.fixationLength(word: word, graphemes: word.count, options: options)
    }

    func testSpecTableAtDefaultStrength() {
        XCTAssertEqual(length("a"), 1)
        XCTAssertEqual(length("to"), 1)
        XCTAssertEqual(length("the"), 2)
        XCTAssertEqual(length("read"), 2)
        XCTAssertEqual(length("smooth"), 3)
        XCTAssertEqual(length("reading"), 4)  // 7 * 0.5 = 3.5 → 4 (round half up)
        XCTAssertEqual(length("2024"), 0)
        XCTAssertEqual(length("naïve"), 3)
    }

    func testAllStrengthsForASevenLetterWord() {
        // 7 graphemes: 1.4→1, 2.45→2, 3.5→4, 4.55→5, 5.6→6
        let expected = [1: 1, 2: 2, 3: 4, 4: 5, 5: 6]
        for (strength, want) in expected {
            XCTAssertEqual(
                length("reading", SmoothOptions(fixation: strength)), want,
                "strength \(strength)")
        }
    }

    func testSingleCharacterNeedsStrengthThree() {
        XCTAssertEqual(length("a", SmoothOptions(fixation: 1)), 0)
        XCTAssertEqual(length("a", SmoothOptions(fixation: 2)), 0)
        XCTAssertEqual(length("a", SmoothOptions(fixation: 3)), 1)
        XCTAssertEqual(length("a", SmoothOptions(fixation: 5)), 1)
    }

    func testRoundHalfUpNeverBankers() {
        // Spec §2: `floor((n * percent + 50) / 100)` in integer arithmetic.
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 1, percent: 50), 1)  // 0.5
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 3, percent: 50), 2)  // 1.5
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 5, percent: 50), 3)  // 2.5: banker's would give 2
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 7, percent: 50), 4)  // 3.5
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 7, percent: 35), 2)  // 2.45
        // 3 * 0.35 is 1.0499… as a Double; the integer form gives exactly 1.
        XCTAssertEqual(SmoothReading.roundHalfUp(graphemes: 3, percent: 35), 1)
        XCTAssertEqual(length("one", SmoothOptions(fixation: 2)), 1)
    }

    func testNumbers() {
        XCTAssertEqual(length("2024"), 0)
        XCTAssertEqual(length("2024", SmoothOptions(emphasizeNumbers: true)), 2)
        XCTAssertEqual(length("5"), 0)
        XCTAssertEqual(length("5", SmoothOptions(emphasizeNumbers: true)), 1)
    }

    func testMinWordLength() {
        let options = SmoothOptions(minWordLength: 4)
        XCTAssertEqual(length("a", options), 0)
        XCTAssertEqual(length("the", options), 0)
        XCTAssertEqual(length("read", options), 2)
    }

    func testFixationIsClampedToOneThroughFive() {
        XCTAssertEqual(length("reading", SmoothOptions(fixation: 0)), 1)
        XCTAssertEqual(length("reading", SmoothOptions(fixation: 9)), 6)
    }

    func testGraphemeClustersNotCodeUnits() {
        let decomposed = "naïve".decomposedStringWithCanonicalMapping
        XCTAssertEqual(decomposed.count, 5)
        XCTAssertEqual(length(decomposed), 3)
        // A flag emoji is a single grapheme cluster made of two scalars.
        XCTAssertEqual("🇯🇵".count, 1)
    }

    func testOverrideReplacesTheAlgorithm() {
        let options = SmoothOptions(fixationLength: { word, _, _ in word.hasPrefix("s") ? 1 : 0 })
        XCTAssertEqual(length("smooth", options), 1)
        XCTAssertEqual(length("reading", options), 0)
        // The result is clamped into 0...graphemes.
        let huge = SmoothOptions(fixationLength: { _, _, _ in 99 })
        XCTAssertEqual(length("to", huge), 2)
        let negative = SmoothOptions(fixationLength: { _, _, _ in -5 })
        XCTAssertEqual(length("to", negative), 0)
    }
}
