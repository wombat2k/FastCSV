@testable import FastCSV
import Foundation
import Testing

@Suite("Adversarial Input Tests")
struct AdversarialTests {

    // MARK: - Malformed Structure

    @Test("Missing columns")
    func testMissingColumns() async throws {
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
            }
        )
    }

    @Test("Extra columns")
    func testExtraColumns() async throws {
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
            }
        )
    }

    // MARK: - Malformed Quoting

    @Test("Unclosed quote")
    func testUnclosedQuote() async throws {
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

                // Check if any row has errors
                let hasErrors = !TestUtils.isErrorFree(arrayResult: results)
                #expect(hasErrors, "Should have at least one row with errors")
            }
        )
    }

    @Test("Unexpected quotes in noQuotes mode")
    func testUnexpectedQuotesInNoQuotesMode() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 2, columns: 3)
        rows[1][1] = "value with \"unexpected\" quotes"

        // Set the parser to noQuotes mode
        let config = CSVParserConfig(assumeNoQuotes: true)

        try await TestUtils.runTest(
            testName: "Unexpected quotes in noQuotes mode",
            contentHeaders: headers,
            contentRows: rows,
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2, "Should have 2 rows")

                // Check if any row has errors
                let hasErrors = !TestUtils.isErrorFree(arrayResult: results)
                #expect(hasErrors, "Should have at least one row with errors")
            }
        )
    }

    // MARK: - Embedded Nulls

    @Test("Null bytes in field values")
    func testNullBytes() async throws {
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

                let value1 = try results[0].values[0].getString() ?? "<nil>"
                #expect(value1 == "before\0after", "Null byte should be preserved in field")

                let value2 = try results[0].values[1].getString() ?? "<nil>"
                #expect(value2 == "normal", "Normal field should be unaffected")

                let value3 = try results[0].values[2].getString() ?? "<nil>"
                #expect(value3 == "also\0has\0nulls", "Multiple null bytes should be preserved")
            }
        )
    }

    // MARK: - Stress Tests

    @Test("Huge field spanning many chunks")
    func testHugeField() async throws {
        let config = CSVParserConfig(readBufferSize: 32)
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

                let value1 = try results[0].values[0].getString() ?? "<nil>"
                #expect(value1 == "small", "First field should be 'small'")

                let value2 = try results[0].values[1].getString() ?? "<nil>"
                #expect(value2 == hugeValue, "Huge field should be preserved (got \(value2.count) chars)")

                let value3 = try results[0].values[2].getString() ?? "<nil>"
                #expect(value3 == "also_small", "Third field should be 'also_small'")
            }
        )
    }

    @Test("Huge quoted field spanning many chunks")
    func testHugeQuotedField() async throws {
        let config = CSVParserConfig(readBufferSize: 32)
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

                let value1 = try results[0].values[0].getString() ?? "<nil>"
                #expect(value1 == innerContent, "Quoted field content should be preserved")

                let value2 = try results[0].values[1].getString() ?? "<nil>"
                #expect(value2 == "normal", "Second field should be 'normal'")
            }
        )
    }

    @Test("Long and wide CSV")
    func testLongAndWideCSV() async throws {
        let headers = TestUtils.createHeaders(count: 100)
        let rows = TestUtils.createValues(rows: 100, columns: 100)

        try await TestUtils.runTest(
            testName: "Long and wide CSV",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 100, "Should have 100 rows")
                #expect(results[0].values.count == 100, "First row should have 100 columns")
                let values = try results.map { try $0.values.map { try $0.getString() } }
                #expect(rows == values)
            }
        )
    }
}
