@testable import FastCSV
import Foundation
import Testing

/// A base test suite for testing the FastCSV parser
enum TestUtils {
    // Output format for testing
    enum OutputFormat {
        case array
        case dictionary
    }

    static func isErrorFree(dictionaryResult: [CSVDictionaryResult]) -> Bool {
        for result in dictionaryResult {
            if let _ = result.error {
                return false
            }
        }
        return true
    }

    static func isErrorFree(arrayResult: [CSVArrayResult]) -> Bool {
        for result in arrayResult {
            if let _ = result.error {
                return false
            }
        }
        return true
    }

    // Create a temporary CSV file from arrays with configurable delimiter
    static func createTemporaryCSVFile(
        headers: [String] = [],
        rows: [[String]] = [[]],
        config: CSVParserConfig = CSVParserConfig()
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).csv")

        var csvContent = ""

        // Convert delimiters to their string representation
        let fieldDelimiter = String(UnicodeScalar(config.delimiter.field))
        let rowDelimiter = String(UnicodeScalar(config.delimiter.row))

        if !headers.isEmpty {
            csvContent = headers.joined(separator: fieldDelimiter)
            csvContent += rowDelimiter
        }

        for row in rows {
            csvContent += row.joined(separator: fieldDelimiter)
            csvContent += rowDelimiter
        }

        try csvContent.data(using: .utf8)?.write(to: tempURL)
        return tempURL
    }

    // Run a test case with arrays for headers and content
    static func runTest<T>(
        testName: String,
        contentHeaders: [String] = [],
        contentRows: [[String]],
        customHeaders: [String] = [],
        config: CSVParserConfig? = nil,
        outputFormat: OutputFormat = .array,
        expectThrow: CSVError? = nil,
        validate: ([T]) throws -> Void
    ) async throws {
        let actualConfig = config ?? CSVParserConfig()
        let fileURL = try createTemporaryCSVFile(headers: contentHeaders, rows: contentRows, config: actualConfig)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            let hasHeaders = !contentHeaders.isEmpty

            let parser = try FastCSV(
                fileURL: fileURL,
                hasHeaders: hasHeaders,
                headers: customHeaders,
                config: actualConfig
            )

            var items: [T] = []

            switch outputFormat {
            case .array:
                guard T.self is CSVArrayResult.Type else {
                    throw ParserTestError(message: "Type mismatch: expected [CSVArrayResult] for array format")
                }

                let rows = try parser.makeValueArrayIterator()

                for result in rows {
                    // Make a safe copy of the values to avoid invalidation
                    let safeArray = result.copyArray()
                    let error = result.error
                    let safeArrayResult = CSVArrayResult(values: safeArray, error: error)
                    items.append(safeArrayResult as! T)
                }
            case .dictionary:
                guard T.self is CSVDictionaryResult.Type else {
                    throw ParserTestError(message: "Type mismatch: expected [CSVDictionaryResult] for dictionary format. Got \(T.self)")
                }

                let rows = try parser.makeValueDictionaryIterator()

                for result in rows {
                    // Make a safef copy of the dictionary to avoid invalidation
                    let safeDictionary = result.copyDictionary()
                    let error = result.error
                    let safeDictionaryResult = CSVDictionaryResult(values: safeDictionary, error: error)

                    items.append(safeDictionaryResult as! T)
                }
            }

            try validate(items)
        } catch let error as CSVError {
            if let expectThrow {
                if error.localizedDescription == expectThrow.localizedDescription {
                    #expect(Bool(true))
                } else {
                    #expect(Bool(false), "Expected error: \(expectThrow), but got: \(error)")
                }
            } else {
                print("❌ Parser failed test '\(testName)': \(error.localizedDescription)")
                throw error // Re-throw to fail the test
            }
        }
    }

    static func createHeaders(count: Int) -> [String] {
        return (1 ..< count + 1).map { "header\($0)" }
    }

    static func createValues(rows: Int, columns: Int) -> [[String]] {
        return (1 ..< rows + 1).map { row in
            (1 ..< columns + 1).map { column in
                "row\(row)_col\(column)"
            }
        }
    }
}

// Error type for parser test failures
struct ParserTestError: Error, CustomStringConvertible {
    let message: String

    init(message: String) {
        self.message = message
    }

    var description: String {
        return message
    }
}
