@testable import FastCSV
import Foundation
import Testing

struct ChunkBoundaryTests {
    private static let tinyBufferSize = 32
    private static let bufferSizes = [8, 16, 32, 64, 128]

    @Test("Minimal chunk boundary test - no headers")
    func minimalChunkBoundary() async throws {
        let config = CSVParserConfig(readBufferSize: Self.tinyBufferSize)
        // 3 columns, 2 rows, no headers — simple enough to trace by hand
        // Row: "row1_col1,row1_col2,row1_col3\n" = 30 bytes + newline = 31 bytes
        let rows = TestUtils.createValues(rows: 2, columns: 3)

        try await TestUtils.runTest(
            testName: "Chunk boundary - minimal",
            contentHeaders: [],
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2, "Should have 2 rows, got \(results.count)")

                for (rowIndex, result) in results.enumerated() {
                    #expect(result.error == nil, "Row \(rowIndex + 1) error: \(String(describing: result.error))")
                    #expect(result.values.count == 3, "Row \(rowIndex + 1) should have 3 columns, got \(result.values.count)")

                    for (colIndex, value) in result.values.enumerated() {
                        let expected = "row\(rowIndex + 1)_col\(colIndex + 1)"
                        let actual = try value.stringIfPresent() ?? "<nil>"
                        #expect(actual == expected, "Row \(rowIndex + 1), Col \(colIndex + 1): expected '\(expected)', got '\(actual)'")
                    }
                }
            }
        )
    }

    @Test("Single wide row spanning multiple chunks")
    func singleWideRow() async throws {
        let config = CSVParserConfig(readBufferSize: Self.tinyBufferSize)
        // Single row, 5 columns, no headers — row is ~50 bytes, needs 2 chunks
        let rows = TestUtils.createValues(rows: 1, columns: 5)

        try await TestUtils.runTest(
            testName: "Chunk boundary - single wide row",
            contentHeaders: [],
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 1, "Should have 1 row, got \(results.count)")
                let result = results[0]
                #expect(result.error == nil, "Row error: \(String(describing: result.error))")
                #expect(result.values.count == 5, "Should have 5 columns, got \(result.values.count)")

                for (colIndex, value) in result.values.enumerated() {
                    let expected = "row1_col\(colIndex + 1)"
                    let actual = try value.stringIfPresent() ?? "<nil>"
                    #expect(actual == expected, "Col \(colIndex + 1): expected '\(expected)', got '\(actual)'")
                }
            }
        )
    }

    @Test("Fields spanning chunk boundaries preserve values", arguments: bufferSizes)
    func fieldsSpanningChunkBoundaries(bufferSize: Int) async throws {
        let config = CSVParserConfig(readBufferSize: bufferSize)
        let headers = TestUtils.createHeaders(count: 5)
        let rows = TestUtils.createValues(rows: 10, columns: 5)

        try await TestUtils.runTest(
            testName: "Chunk boundary - basic values (buffer: \(bufferSize))",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 10, "Should have 10 rows, got \(results.count)")

                for (rowIndex, result) in results.enumerated() {
                    #expect(result.error == nil, "Row \(rowIndex + 1) should not have an error")
                    #expect(result.values.count == 5, "Row \(rowIndex + 1) should have 5 columns, got \(result.values.count)")

                    for (colIndex, value) in result.values.enumerated() {
                        let expected = "row\(rowIndex + 1)_col\(colIndex + 1)"
                        let actual = try value.stringIfPresent() ?? "<nil>"
                        #expect(actual == expected, "Row \(rowIndex + 1), Col \(colIndex + 1): expected '\(expected)', got '\(actual)'")
                    }
                }
            }
        )
    }

    @Test("Dictionary access with tiny buffer")
    func dictionaryChunkBoundaries() async throws {
        let config = CSVParserConfig(readBufferSize: Self.tinyBufferSize)
        let headers = TestUtils.createHeaders(count: 5)
        let rows = TestUtils.createValues(rows: 10, columns: 5)

        try await TestUtils.runTest(
            testName: "Chunk boundary - dictionary",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(results.count == 10, "Should have 10 rows, got \(results.count)")

                for (rowIndex, result) in results.enumerated() {
                    #expect(result.error == nil, "Row \(rowIndex + 1) should not have an error")
                    #expect(result.values.count == 5, "Row \(rowIndex + 1) should have 5 columns, got \(result.values.count)")

                    for colIndex in 1 ... 5 {
                        let key = "header\(colIndex)"
                        let expected = "row\(rowIndex + 1)_col\(colIndex)"
                        let actual = try result[key]?.stringIfPresent() ?? "<nil>"
                        #expect(actual == expected, "Row \(rowIndex + 1), '\(key)': expected '\(expected)', got '\(actual)'")
                    }
                }
            }
        )
    }
}
