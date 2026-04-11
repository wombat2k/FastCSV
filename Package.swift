// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FastCSV",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "FastCSV",
            targets: ["FastCSV"],
        ),
    ],
    targets: [
        .target(
            name: "FastCSV",
            swiftSettings: [
                // Debug logging is disabled by default
                // Uncomment the next line to enable debug logs during development
                // .define("ENABLE_LOGGING"),
            ],
        ),
        .testTarget(
            name: "FastCSVTests",
            dependencies: ["FastCSV"],
            path: "Tests/FastCSVTests",
            exclude: [],
        ),
    ],
)
