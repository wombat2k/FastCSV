@testable import FastCSV
import Foundation
import Testing

struct AdversarialTests {
    private static let tinyBufferSize = 32

    // MARK: - Malformed Structure

    @Test
    func `Missing columns`() async throws {
        let headers = TestUtils.createHeaders(count: 3)

        var rows = TestUtils.createValues(rows: 2, columns: 3)
        // Modify second row to have fewer columns
        rows[1] = [rows[1][0], rows[1][1]] // Remove the last column

        try await TestUtils.runTest(
            testName: "Unbalanced columns",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2, "Should have 2 rows")
                #expect(results[0].error == nil, "First row should not have an error")

                // We expect the second row to have an error
                #expect(results[1].error != nil, "Second row should have an error")

                // The error should be a CSVError
                if let csvError = results[1].error {
                    switch csvError {
                    case let .rowError(row, message):
                        #expect(row == 3, "Error should mention row 3")
                        #expect(message.contains("columns"), "Error should mention columns")
                    default:
                        #expect(Bool(false), "Expected invalidCSV error but got \(csvError)")
                    }
                } else {
                    #expect(Bool(false), "Expected CSVError type but got \(type(of: results[1].error!))")
                }
            },
        )
    }

    @Test
    func `Extra columns`() async throws {
        let headers = TestUtils.createHeaders(count: 3)

        var rows = TestUtils.createValues(rows: 2, columns: 3)
        // Add an extra column to the second row
        rows[1].append("extra_value")

        try await TestUtils.runTest(
            testName: "Unbalanced columns",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2, "Should have 2 rows")
                #expect(results[0].error == nil, "First row should not have an error")

                // We expect the second row to have an error
                #expect(results[1].error != nil, "Second row should have an error")

                // The number of columns should be 3
                #expect(results[1].values.count == 3, "Second row should have 3 columns")

                // The error should be a CSVError
                if let csvError = results[1].error {
                    switch csvError {
                    case let .rowError(row, message):
                        #expect(row == 3, "Error should mention row 3")
                        #expect(message.contains("columns"), "Error should mention columns")
                    default:
                        #expect(Bool(false), "Expected invalidCSV error but got \(csvError)")
                    }
                } else {
                    #expect(Bool(false), "Expected CSVError type but got \(type(of: results[1].error!))")
                }
            },
        )
    }

    // MARK: - Malformed Quoting

    @Test
    func `Unclosed quote`() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "\"value with unfinished quote", "value3"],
        ]

        try await TestUtils.runTest(
            testName: "Unclosed quote",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 1, "Should have 1 row")

                if let error = results[0].error {
                    switch error {
                    case let .rowError(_, message):
                        #expect(message.contains("unclosed quote"), "Error should mention unclosed quote")
                    default:
                        #expect(Bool(false), "Expected rowError but got \(error)")
                    }
                } else {
                    #expect(Bool(false), "Should have an error for unclosed quote")
                }
            },
        )
    }

    @Test
    func `Quotes treated as literal characters in noQuotes mode`() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 2, columns: 3)
        rows[1][1] = "value with \"unexpected\" quotes"

        // In noQuotes mode, quotes are just regular bytes — no special handling
        let config = CSVParserConfig(assumeNoQuotes: true)

        try await TestUtils.runTest(
            testName: "Quotes treated as literal in noQuotes mode",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2, "Should have 2 rows")
                #expect(results[0].error == nil, "First row should not have an error")
                #expect(results[1].error == nil, "Second row should not have an error")

                let value = try results[1].values[1].stringIfPresent() ?? ""
                #expect(value == "value with \"unexpected\" quotes",
                        "Quotes should be preserved as literal characters")
            },
        )
    }

    // MARK: - Embedded Nulls

    @Test
    func `Null bytes in field values`() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = [
            ["before\0after", "normal", "also\0has\0nulls"],
        ]

        try await TestUtils.runTest(
            testName: "Null bytes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "Should not have an error")
                #expect(results[0].values.count == 3, "Should have 3 columns")

                let value1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
                #expect(value1 == "before\0after", "Null byte should be preserved in field")

                let value2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
                #expect(value2 == "normal", "Normal field should be unaffected")

                let value3 = try results[0].values[2].stringIfPresent() ?? "<nil>"
                #expect(value3 == "also\0has\0nulls", "Multiple null bytes should be preserved")
            },
        )
    }

    // MARK: - Stress Tests

    @Test
    func `Huge field spanning many chunks`() async throws {
        let config = CSVParserConfig(readBufferSize: Self.tinyBufferSize)
        // Create a field that's ~500 bytes — spans ~16 chunks at 32 bytes each
        let hugeValue = String(repeating: "x", count: 500)
        let headers = TestUtils.createHeaders(count: 3)
        let rows = [
            ["small", hugeValue, "also_small"],
        ]

        try await TestUtils.runTest(
            testName: "Huge field",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "Should not have an error: \(String(describing: results[0].error))")
                #expect(results[0].values.count == 3, "Should have 3 columns, got \(results[0].values.count)")

                let value1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
                #expect(value1 == "small", "First field should be 'small'")

                let value2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
                #expect(value2 == hugeValue, "Huge field should be preserved (got \(value2.count) chars)")

                let value3 = try results[0].values[2].stringIfPresent() ?? "<nil>"
                #expect(value3 == "also_small", "Third field should be 'also_small'")
            },
        )
    }

    @Test
    func `Huge quoted field spanning many chunks`() async throws {
        let config = CSVParserConfig(readBufferSize: Self.tinyBufferSize)
        // Quoted field with commas and newlines inside, ~300 bytes
        let innerContent = String(repeating: "data,with,commas\nand\nnewlines\n", count: 10)
        let quotedValue = "\"\(innerContent)\""
        let headers = TestUtils.createHeaders(count: 2)
        let rows = [
            [quotedValue, "normal"],
        ]

        try await TestUtils.runTest(
            testName: "Huge quoted field",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "Should not have an error: \(String(describing: results[0].error))")
                #expect(results[0].values.count == 2, "Should have 2 columns, got \(results[0].values.count)")

                let value1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
                #expect(value1 == innerContent, "Quoted field content should be preserved")

                let value2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
                #expect(value2 == "normal", "Second field should be 'normal'")
            },
        )
    }

    private static let gridSizes = [
        (rows: 10, columns: 10),
        (rows: 100, columns: 100),
        (rows: 10, columns: 1000),
        (rows: 1000, columns: 10),
    ]

    @Test(arguments: gridSizes)
    func `Long and wide CSV`(rows rowCount: Int, columns colCount: Int) async throws {
        let headers = TestUtils.createHeaders(count: colCount)
        let rows = TestUtils.createValues(rows: rowCount, columns: colCount)

        try await TestUtils.runTest(
            testName: "Long and wide CSV (\(rowCount)x\(colCount))",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == rowCount, "Should have \(rowCount) rows")
                #expect(results[0].values.count == colCount, "First row should have \(colCount) columns")
                let values = try results.map { try $0.values.map { try $0.stringIfPresent() } }
                #expect(rows == values)
            },
        )
    }
}
