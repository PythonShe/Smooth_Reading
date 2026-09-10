// swift-tools-version: 6.0
// SmoothReading — guided fixation reading. Apache-2.0.
// Zero dependencies: only Foundation (ICU) is used.

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
        .target(name: "SmoothReading"),
        .testTarget(name: "SmoothReadingTests", dependencies: ["SmoothReading"]),
    ]
)
