@testable import FastCSV
import Foundation
import Testing

@Suite("Invalid CSV Tests")
struct InvalidCSVTests {
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

    @Test("Invalid quotes", .disabled())
    func testInvalidQuotes() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value with \"unfinished quote", "value3"],
        ]

        try await TestUtils.runTest(
            testName: "Invalid quotes",
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
}
