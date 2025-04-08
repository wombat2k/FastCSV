// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FastCSV",
    platforms: [
        .macOS(.v15),
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
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.8.0"),
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
            dependencies: ["FastCSV"]
        ),
        .executableTarget(
            name: "CSVBenchmark",
            dependencies: [
                "FastCSV",
                "SwiftCSV",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
