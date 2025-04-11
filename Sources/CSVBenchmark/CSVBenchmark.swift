import ArgumentParser
import FastCSV
import Foundation

/// A command-line tool for benchmarking CSV parsing performance.
@main
struct CSVBenchmarkTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "csvbenchmark",
        abstract: "A tool for benchmarking CSV parsing performance",
        version: "1.0.0"
    )

    // Input file option (required)
    @Argument(help: "Path to a CSV file to benchmark")
    var file: String

    // Row limit options
    @Option(name: .long, help: "Limit the number of rows to process (default: 10000, use 0 for no limit)")
    var rowLimit: Int = 10000

    // Temporary file handling
    @Flag(name: .long, help: "Skip copying to temporary location")
    var skipTemp = false

    // Option to enable file caching (disabled by default for accurate benchmarking)
    @Flag(name: .long, help: "Enable OS file caching (may skew benchmark results)")
    var enableCache = false

    // Option to assume no quotes in CSV data for improved parsing performance
    @Flag(name: .long, help: "Assume CSV data contains no quoted fields for improved performance")
    var assumeNoQuotes = false

    // Run multiple iterations and report statistical measures
    @Option(name: .long, help: "Number of iterations for statistical benchmarking")
    var iterations: Int = 10

    mutating func run() throws {
        print("CSV Benchmark Tool")
        print("=================")

        // Validate file exists
        guard FileManager.default.fileExists(atPath: file) else {
            throw ValidationError("File not found: \(file)")
        }

        print("File: \(URL(fileURLWithPath: file).lastPathComponent)")

        // Set row limit (0 means no limit)
        let limit = rowLimit > 0 ? rowLimit : nil
        if let limit = limit {
            print("Limiting benchmark to \(limit) rows")
        }

        // Run the benchmark
        var measurements: [Double] = []
        var bestResult: BenchmarkResult?
        var tempFiles: [String] = []

        // Create temporary files for each iteration
        if !skipTemp {
            print("Creating temporary files for benchmarks...")
            for _ in 0 ..< iterations {
                let tempFile = try copyToTemporaryLocation(file, enableCache: enableCache)
                tempFiles.append(tempFile)
            }

            if !enableCache {
                print("File caching disabled (for accurate I/O benchmarks)")
            }
        }

        defer {
            if !skipTemp {
                // Clean up temporary files
                for tempFile in tempFiles {
                    try? FileManager.default.removeItem(atPath: tempFile)
                }
                print("Cleaned up \(tempFiles.count) temporary files")
            }
        }

        for i in 0 ..< iterations {
            // Use original file or the dedicated temporary file for this iteration
            let benchmarkFile = skipTemp ? file : tempFiles[i]

            let result = try runBenchmark(
                file: benchmarkFile,
                rowLimit: limit
            )
            measurements.append(result.parseTime)

            // Store the best result (for detailed output later)
            if bestResult == nil || result.parseTime < bestResult!.parseTime {
                bestResult = result
            }

            print("Run \(i + 1)/\(iterations): \(String(format: "%.4f", result.parseTime)) seconds")
        }

        // Calculate statistics
        let mean = measurements.reduce(0, +) / Double(measurements.count)
        let sortedMeasurements = measurements.sorted()
        let median = measurements.count % 2 == 0
            ? (sortedMeasurements[measurements.count / 2] + sortedMeasurements[measurements.count / 2 - 1]) / 2
            : sortedMeasurements[measurements.count / 2]
        let min = measurements.min() ?? 0
        let max = measurements.max() ?? 0
        let variance = measurements.reduce(0) { $0 + pow($1 - mean, 2) } / Double(measurements.count)
        let stdDev = sqrt(variance)
        let relativeStdDev = (stdDev / mean) * 100

        print("\nStatistical Results:")
        print("Mean:      \(String(format: "%.4f", mean)) seconds")
        print("Median:    \(String(format: "%.4f", median)) seconds")
        print("Min:       \(String(format: "%.4f", min)) seconds")
        print("Max:       \(String(format: "%.4f", max)) seconds")
        print("Std Dev:   \(String(format: "%.4f", stdDev)) seconds")
        print("RSD:       \(String(format: "%.2f", relativeStdDev))%")

        // Print detailed results for best run
        if let result = bestResult {
            printDetailedResults(result: result)
        }
    }

    // Copy file to temporary location
    func copyToTemporaryLocation(_ filePath: String, enableCache: Bool = false) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let tempFilePath = tempDir.appendingPathComponent("csvbenchmark-\(UUID().uuidString)-\(fileName)").path

        // Copy the file first
        try FileManager.default.copyItem(atPath: filePath, toPath: tempFilePath)

        if !enableCache {
            #if os(macOS)
                // On macOS, open the file with F_NOCACHE to hint that this file should not be cached
                if let fileHandle = FileHandle(forWritingAtPath: tempFilePath) {
                    let fd = fileHandle.fileDescriptor
                    // Set F_NOCACHE flag to disable caching
                    _ = fcntl(fd, F_NOCACHE, 1)
                    fileHandle.closeFile()
                }
            #endif
        }

        return tempFilePath
    }

    // Run benchmark
    func runBenchmark(file: String, rowLimit: Int?) throws -> BenchmarkResult {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: file)[.size] as? UInt64) ?? 0
        let fileSizeMB = Double(fileSize) / (1024 * 1024)

        var result = BenchmarkResult(
            timeElapsed: 0,
            initTime: 0,
            parseTime: 0,
            rowCount: 0,
            fileSize: fileSizeMB
        )

        let startTime = DispatchTime.now()

        // Init phase
        let initStart = DispatchTime.now()

        // Create parser config with assumeNoQuotes setting
        let config = CSVParserConfig(assumeNoQuotes: assumeNoQuotes)

        let parser = try FastCSV(
            fileURL: URL(fileURLWithPath: file),
            config: config
        )
        var iterator = try parser.makeValueArrayIterator()
        let initEnd = DispatchTime.now()
        result.initTime = Double(initEnd.uptimeNanoseconds - initStart.uptimeNanoseconds) / 1_000_000_000

        // Parse phase
        let parseStart = DispatchTime.now()
        var rowCount = 0
        let rowsToProcess = rowLimit ?? Int.max
        while let _ = iterator.next(), rowCount < rowsToProcess {
            rowCount += 1
        }
        let parseEnd = DispatchTime.now()
        result.parseTime = Double(parseEnd.uptimeNanoseconds - parseStart.uptimeNanoseconds) / 1_000_000_000
        result.rowCount = rowCount

        let endTime = DispatchTime.now()
        result.timeElapsed = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000

        // Calculate performance metrics
        result.rowsPerSecond = Double(result.rowCount) / result.timeElapsed
        result.mbPerSecond = fileSizeMB / result.timeElapsed

        return result
    }

    // Print detailed benchmark results
    func printDetailedResults(result: BenchmarkResult) {
        print("\nBest Run Details:")
        print("----------------")
        print("Total time:       \(String(format: "%.4f", result.timeElapsed)) seconds")
        print("Init time:        \(String(format: "%.4f", result.initTime)) seconds")
        print("Parse time:       \(String(format: "%.4f", result.parseTime)) seconds")
        print("Rows processed:   \(result.rowCount)")
        print("Rows per second:  \(Int(result.rowsPerSecond))")
        print("File size:        \(String(format: "%.2f", result.fileSize)) MB")
        print("Processing speed: \(String(format: "%.2f", result.mbPerSecond)) MB/second")

        // Add info about whether assumeNoQuotes was enabled
        if assumeNoQuotes {
            print("Quote handling:   Disabled (assumeNoQuotes)")
        } else {
            print("Quote handling:   Enabled (standard CSV parsing)")
        }
    }
}

// Benchmark result structure
struct BenchmarkResult {
    var timeElapsed: Double
    var initTime: Double
    var parseTime: Double
    var rowCount: Int
    let fileSize: Double
    var rowsPerSecond: Double = 0
    var mbPerSecond: Double = 0
}
