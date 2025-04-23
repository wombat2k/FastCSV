// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FastCSV",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "FastCSV",
            targets: ["FastCSV"]
        ),
        .executable(name: "CSVBenchmark", targets: ["CSVBenchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "FastCSV",
            swiftSettings: [
                // Debug logging is disabled by default
                // Uncomment the next line to enable debug logs during development
                // .define("ENABLE_LOGGING"),
            ]
        ),
        .testTarget(
            name: "FastCSVTests",
            dependencies: ["FastCSV"],
            path: "Tests/FastCSVTests",
            exclude: []
        ),
        .executableTarget(
            name: "CSVBenchmark",
            dependencies: [
                "FastCSV",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
