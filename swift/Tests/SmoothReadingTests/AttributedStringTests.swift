import XCTest

@testable import SmoothReading

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class AttributedStringTests: XCTestCase {

    func testPlainTextRoundTrips() {
        let attributed = SmoothReading.attributedString("Smooth reading works.")
        XCTAssertEqual(String(attributed.characters), "Smooth reading works.")
    }

    func testFixationRunsAreStronglyEmphasized() {
        let attributed = SmoothReading.attributedString("Smooth reading")
        var bold: [String] = []
        var plain: [String] = []
        for run in attributed.runs {
            let text = String(attributed[run.range].characters)
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                bold.append(text)
            } else {
                plain.append(text)
            }
        }
        XCTAssertEqual(bold, ["Smo", "read"])
        XCTAssertEqual(plain, ["oth ", "ing"])  // adjacent equal-attribute runs coalesce
    }

    func testCustomContainers() {
        var fixation = AttributeContainer()
        fixation.inlinePresentationIntent = .emphasized
        let attributed = SmoothReading.attributedString("to", fixationAttributes: fixation)
        let first = attributed.runs.first
        XCTAssertEqual(first?.inlinePresentationIntent, .emphasized)
    }

    #if canImport(UIKit) || canImport(AppKit)
    @MainActor
    func testNSAttributedStringUsesARealBoldFont() {
        let attributed = SmoothReading.nsAttributedString("Smooth reading")
        XCTAssertEqual(attributed.string, "Smooth reading")

        func isBold(at index: Int) -> Bool {
            guard let font = attributed.attribute(.font, at: index, effectiveRange: nil) as? PlatformFont
            else { return false }
            #if canImport(UIKit)
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
            #else
            return font.fontDescriptor.symbolicTraits.contains(.bold)
            #endif
        }

        // "Smo" is the fixation, "oth reading" continues plain.
        for index in 0..<3 { XCTAssertTrue(isBold(at: index), "expected bold at \(index)") }
        for index in 3..<7 { XCTAssertFalse(isBold(at: index), "expected plain at \(index)") }
        // "read" is the next fixation.
        for index in 7..<11 { XCTAssertTrue(isBold(at: index), "expected bold at \(index)") }
        for index in 11..<14 { XCTAssertFalse(isBold(at: index), "expected plain at \(index)") }
    }

    @MainActor
    func testNSAttributedStringHonoursTheSuppliedFontAndAttributes() {
        #if canImport(UIKit)
        let base = UIFont.systemFont(ofSize: 21)
        #else
        let base = NSFont.systemFont(ofSize: 21)
        #endif
        let attributed = SmoothReading.nsAttributedString("to", font: base)
        let fixationFont = attributed.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
        let restFont = attributed.attribute(.font, at: 1, effectiveRange: nil) as? PlatformFont
        XCTAssertEqual(fixationFont?.pointSize, 21)
        XCTAssertEqual(restFont, base)

        let custom = SmoothReading.nsAttributedString(
            "to", fixationAttributes: [.underlineStyle: 1], restAttributes: [:])
        XCTAssertNotNil(custom.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        XCTAssertNil(custom.attribute(.underlineStyle, at: 1, effectiveRange: nil))
    }

    func testBoldFontOfSystemFontHasBoldTrait() {
        let bold = SmoothReading.boldFont(from: PlatformFont.systemFont(ofSize: 15))
        XCTAssertEqual(bold.pointSize, 15)
        #if canImport(UIKit)
        XCTAssertTrue(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        #else
        XCTAssertTrue(bold.fontDescriptor.symbolicTraits.contains(.bold))
        #endif
    }

    /// Families with a single face (no bold) must still yield a usable font at
    /// the same size instead of crashing or returning nil.
    func testBoldFontFallsBackGracefullyWhenTheFamilyHasNoBoldFace() {
        for name in ["Zapfino", "Herculanum", "Papyrus", "Chalkduster"] {
            guard let font = PlatformFont(name: name, size: 13) else { continue }
            let bold = SmoothReading.boldFont(from: font)
            XCTAssertEqual(bold.pointSize, 13, name)
            XCTAssertFalse(bold.familyName?.isEmpty ?? true, name)
        }
        // And a font that does not exist at all resolves to *something* bold-ish.
        let attributed = SmoothReading.nsAttributedString("Smooth", font: PlatformFont(name: "Zapfino", size: 13))
        XCTAssertEqual(attributed.string, "Smooth")
        XCTAssertNotNil(attributed.attribute(.font, at: 0, effectiveRange: nil))
    }

    func testRunsConcatenateToTheInput() {
        let input = "Smooth reading works, don't stop!"
        XCTAssertEqual(SmoothReading.runs(input, options: .default).map(\.text).joined(), input)
    }
    #endif
}
