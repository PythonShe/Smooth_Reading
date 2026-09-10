import XCTest

@testable import SmoothReading

/// Runs the shared fixtures in `fixtures/` (see `docs/SPEC.md` §7).
/// `common` must pass in every port; `segmenter` only where an ICU word
/// breaker exists — which is the case here.
final class FixtureTests: XCTestCase {

    private struct FixtureOptions: Decodable {
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

    private struct FixtureCase: Decodable {
        var name: String
        var input: String
        var options: FixtureOptions?
        var html: String
    }

    /// `swift/Tests/SmoothReadingTests/FixtureTests.swift` → repo root → `fixtures/`.
    private static var fixturesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SmoothReadingTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // swift
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("fixtures")
    }

    func testCommonFixtures() throws {
        try run(suite: "common")
    }

    /// The `common` fixtures must also pass through the locale-aware
    /// (`CFStringTokenizer`) path, which is only used when a locale is set.
    func testCommonFixturesThroughTheLocaleAwareTokenizer() throws {
        try run(suite: "common", forcingLocale: Locale(identifier: "en_US"))
    }

    func testSegmenterFixtures() throws {
        try run(suite: "segmenter")
    }

    /// Loads every `.json` case file of a suite. Missing or empty suites are
    /// failures, never skips: every port must run all of them.
    private static func cases(in suite: String) throws -> [(file: String, cases: [FixtureCase])] {
        let directory = fixturesRoot.appendingPathComponent(suite)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            XCTFail("fixtures/\(suite) does not exist at \(directory.path)")
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(files.isEmpty, "fixtures/\(suite) contains no .json files")
        return try files.map { file in
            (file.lastPathComponent, try JSONDecoder().decode([FixtureCase].self, from: Data(contentsOf: file)))
        }
    }

    private func run(suite: String, forcingLocale: Locale? = nil) throws {
        var count = 0
        for (file, cases) in try Self.cases(in: suite) {
            for fixture in cases {
                var options = SmoothOptions()
                var htmlOptions = HtmlOptions()
                if let json = fixture.options {
                    if let value = json.fixation { options.fixation = value }
                    if let value = json.saccade { options.saccade = value }
                    if let value = json.minWordLength { options.minWordLength = value }
                    if let value = json.emphasizeNumbers { options.emphasizeNumbers = value }
                    if let value = json.locale { options.locale = Locale(identifier: value) }
                    if let value = json.tag { htmlOptions.tag = value }
                    if let value = json.className { htmlOptions.className = value }
                    if let value = json.restTag { htmlOptions.restTag = value }
                    if let value = json.restClassName { htmlOptions.restClassName = value }
                    if let value = json.ignoreHtmlTags { htmlOptions.ignoreHtmlTags = value }
                    if let value = json.skipTags { htmlOptions.skipTags = Set(value) }
                }
                if let forcingLocale { options.locale = forcingLocale }
                htmlOptions.options = options
                let actual = SmoothReading.html(fixture.input, options: htmlOptions)
                XCTAssertEqual(actual, fixture.html, "\(suite)/\(file): \(fixture.name)")
                count += 1
            }
        }
        XCTAssertGreaterThan(count, 0, "fixtures/\(suite) ran no cases")
    }
}
