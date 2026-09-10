// swift-tools-version: 6.0
// SmoothReading — guided fixation reading. Apache-2.0.
// Zero dependencies: only Foundation (ICU) is used.

import PackageDescription

let package = Package(
    name: "SmoothReading",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
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
