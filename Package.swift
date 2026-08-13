// swift-tools-version: 5.9
import PackageDescription

// Zero package dependencies is a hard invariant of this package: CI fails the
// build if `swift package show-dependencies` reports anything at all.
let package = Package(
    name: "bundlefacts",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "BundleFacts", targets: ["BundleFacts"]),
    ],
    targets: [
        .target(name: "BundleFacts"),
        .testTarget(
            name: "BundleFactsTests",
            dependencies: ["BundleFacts"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
