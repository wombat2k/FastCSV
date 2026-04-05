// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FastCSVExamples",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(name: "Filtering", dependencies: ["FastCSV"]),
        .executableTarget(name: "Aggregation", dependencies: ["FastCSV"]),
        .executableTarget(name: "Writing", dependencies: ["FastCSV"]),
        .executableTarget(name: "RawAccess", dependencies: ["FastCSV"]),
    ],
)
