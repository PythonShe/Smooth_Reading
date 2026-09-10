// swift-tools-version: 6.0
// SmoothReading — guided fixation reading. Apache-2.0.
//
// Root manifest so `.package(url: "https://github.com/PythonShe/Smooth_Reading.git", …)`
// resolves directly: SwiftPM only reads a Package.swift at the repository
// root. It declares the same targets as `swift/Package.swift`, pointing at the
// sources under `swift/`. Keep both manifests in sync.

import PackageDescription

let package = Package(
    name: "SmoothReading",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SmoothReading", targets: ["SmoothReading"])
    ],
    targets: [
        .target(name: "SmoothReading", path: "swift/Sources/SmoothReading"),
        .testTarget(
            name: "SmoothReadingTests",
            dependencies: ["SmoothReading"],
            path: "swift/Tests/SmoothReadingTests"
        ),
    ]
)
