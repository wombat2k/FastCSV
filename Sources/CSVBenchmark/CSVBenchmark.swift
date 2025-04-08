import ArgumentParser
import FastCSV
import Foundation
import SwiftCSV

/// A command-line tool for benchmarking CSV parsing performance.
/// This tool allows you to benchmark a specific CSV parser with a specific file
@main
struct CSVBenchmarkTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "csvbenchmark",
        abstract: "A tool for benchmarking CSV parsing performance",
        version: "1.0.0"
    )

    // Parser selection
    @Option(name: .shortAndLong, help: "Parser to use (streaming, inMemory, swiftcsv)")
    var parser: String

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

    mutating func run() throws {
        print("CSV Single-Parser Benchmark Tool")
        print("===============================")

        // Validate parser choice
        let parserType = try validateParser(parser)

        // Validate file exists
        guard FileManager.default.fileExists(atPath: file) else {
            throw ValidationError("File not found: \(file)")
        }

        // Copy file to temporary location if needed
        let benchmarkFile: String
        if skipTemp {
            benchmarkFile = file
            print("Using original file: \(benchmarkFile)")
        } else {
            benchmarkFile = try copyToTemporaryLocation(file, enableCache: enableCache)
            print("Copied to temporary location: \(benchmarkFile)")
            if !enableCache {
                print("File caching disabled (for accurate I/O benchmarks)")
            }
        }

        defer {
            if !skipTemp {
                // Clean up temporary file only if we created one
                try? FileManager.default.removeItem(atPath: benchmarkFile)
                print("Cleaned up temporary file")
            }
        }

        // Set row limit (0 means no limit)
        let limit = rowLimit > 0 ? rowLimit : nil
        if let limit = limit {
            print("Limiting benchmark to \(limit) rows")
        }

        print("Running benchmark with parser: \(parserType)")
        print("File: \(URL(fileURLWithPath: file).lastPathComponent)")

        // Run the benchmark
        let result = try runSingleBenchmark(
            file: benchmarkFile,
            parserType: parserType,
            rowLimit: limit
        )

        // Print detailed results
        printDetailedResults(result: result)
    }

    // Validate and convert parser string to enum
    func validateParser(_ parserString: String) throws -> ParserType {
        switch parserString.lowercased() {
        case "inMemory":
            return .inMemory
        case "streaming":
            return .streaming
        case "swiftcsv":
            return .swiftCSV
        default:
            throw ValidationError("Invalid parser: \(parserString). Valid options are: simd, async, mmap, swiftcsv")
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

    // Run a single benchmark with the specified parser
    func runSingleBenchmark(file: String, parserType: ParserType, rowLimit: Int?) throws -> BenchmarkResult {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: file)[.size] as? UInt64) ?? 0
        let fileSizeMB = Double(fileSize) / (1024 * 1024)

        var result = BenchmarkResult(
            name: parserType.description,
            timeElapsed: 0,
            initTime: 0,
            parseTime: 0,
            rowCount: 0,
            fileSize: fileSizeMB
        )

        let startTime = DispatchTime.now()

        switch parserType {
        case .inMemory, .streaming:
            let (initTime, parseTime, rowCount) = try benchmarkFastCSV(
                file: file,
                parsingMode: parserTypeToParsingMode(parserType),
                rowLimit: rowLimit
            )
            result.initTime = initTime
            result.parseTime = parseTime
            result.rowCount = rowCount

        case .swiftCSV:
            let (initTime, parseTime, rowCount) = try benchmarkSwiftCSV(
                file: file,
                rowLimit: rowLimit
            )
            result.initTime = initTime
            result.parseTime = parseTime
            result.rowCount = rowCount
        }

        let endTime = DispatchTime.now()
        result.timeElapsed = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000

        // Calculate performance metrics
        result.rowsPerSecond = Double(result.rowCount) / result.timeElapsed
        result.mbPerSecond = fileSizeMB / result.timeElapsed

        return result
    }

    // Helper function to convert ParserType to FastCSV's ParsingMode
    private func parserTypeToParsingMode(_ parserType: ParserType) -> ParsingMode {
        switch parserType {
        case .streaming: return .streaming
        case .inMemory: return .inMemory
        case .swiftCSV: fatalError("Should not be called with swiftCSV")
        }
    }

    // Benchmark FastCSV parsers
    private func benchmarkFastCSV(
        file: String,
        parsingMode _: ParsingMode,
        rowLimit _: Int?
    ) throws -> (initTime: Double, parseTime: Double, rowCount: Int) {
        let initStart = DispatchTime.now()
        let parser = try FastCSV(
            fileURL: URL(fileURLWithPath: file)
        )
        var iterator = try parser.makeValueArrayIterator()
        let initEnd = DispatchTime.now()
        let initTime = Double(initEnd.uptimeNanoseconds - initStart.uptimeNanoseconds) / 1_000_000_000

        let parseStart = DispatchTime.now()
        var rowCount = 0
        while let _ = iterator.next() {
            rowCount += 1
        }
        let parseEnd = DispatchTime.now()
        let parseTime = Double(parseEnd.uptimeNanoseconds - parseStart.uptimeNanoseconds) / 1_000_000_000

        return (initTime, parseTime, rowCount)
    }

    // Benchmark SwiftCSV parser
    private func benchmarkSwiftCSV(
        file: String,
        rowLimit: Int?
    ) throws -> (initTime: Double, parseTime: Double, rowCount: Int) {
        let initStart = DispatchTime.now()
        let parser: CSV<Enumerated>
        do {
            parser = try CSV<Enumerated>(url: URL(fileURLWithPath: file))
        } catch {
            throw error
        }
        let initEnd = DispatchTime.now()
        let initTime = Double(initEnd.uptimeNanoseconds - initStart.uptimeNanoseconds) / 1_000_000_000

        var processedRows = 0
        let parseStart = DispatchTime.now()
        try parser.enumerateAsArray(startAt: 0, rowLimit: rowLimit) { _ in
            processedRows += 1
        }
        let parseEnd = DispatchTime.now()
        let parseTime = Double(parseEnd.uptimeNanoseconds - parseStart.uptimeNanoseconds) / 1_000_000_000

        return (initTime, parseTime, processedRows)
    }

    // Print detailed benchmark results
    func printDetailedResults(result: BenchmarkResult) {
        print("\nBenchmark Results:")
        print("------------------")
        print("Parser:           \(result.name)")
        print("Total time:       \(String(format: "%.4f", result.timeElapsed)) seconds")
        print("Init time:        \(String(format: "%.4f", result.initTime)) seconds")
        print("Parse time:       \(String(format: "%.4f", result.parseTime)) seconds")
        print("Rows processed:   \(result.rowCount)")
        print("Rows per second:  \(Int(result.rowsPerSecond))")
        print("File size:        \(String(format: "%.2f", result.fileSize)) MB")
        print("Processing speed: \(String(format: "%.2f", result.mbPerSecond)) MB/second")
    }
}

// Parser type enum
enum ParserType: CustomStringConvertible {
    case inMemory
    case streaming
    case swiftCSV

    var description: String {
        switch self {
        case .inMemory: return "In-Memory"
        case .streaming: return "Streaming"
        case .swiftCSV: return "SwiftCSV"
        }
    }
}

// Benchmark result structure
struct BenchmarkResult {
    let name: String
    var timeElapsed: Double
    var initTime: Double
    var parseTime: Double
    var rowCount: Int
    let fileSize: Double
    var rowsPerSecond: Double = 0
    var mbPerSecond: Double = 0
}

// Parsing modes
enum ParsingMode: String, CaseIterable {
    case streaming
    case inMemory
}
