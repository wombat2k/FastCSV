@testable import FastCSV
import Foundation
import Testing

@Suite("Empty Values Tests")
struct EdgeDelimiterTests {
    // MARK: Header Tests

    @Test("Empty value at beginning of headers")
    func testFrontDelimiterAtHeaders() async throws {
        let headers = ["", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty value at beginning of headers",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")

                let value = try rows[0]["column_1"]?.getString() ?? ""
                #expect(value == "value1", "First header should have default name 'column_1'.")
            }
        )
    }

    @Test("Empty value at middle of headers")
    func testMiddleDelimiterAtHeaders() async throws {
        let headers = ["header1", "", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty value at middle of headers",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                let value = try rows[0]["column_2"]?.getString() ?? ""
                #expect(value != "value1", "Second header should have default name 'column_2'.")
            }
        )
    }

    @Test("Empty value at end of headers")
    func testTrailingDelimiterAtHeaders() async throws {
        let headers = ["header1", "header2", ""]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty value at end of headers",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                let value = try rows[0]["column_3"]?.getString() ?? ""
                #expect(value != "value1", "Last header should have default name 'column_3'.")
            }
        )
    }

    // MARK: Row Tests

    @Test("Empty value at beginning of row")
    func testFrontDelimiter() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value2", "value3"],
            ["", "value2", "value3"],
            ["value1", "value2", "value3"],
        ]

        try await TestUtils.runTest(
            testName: "Empty value at beginning of row",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 3, "Should have 3 rows")

                // Check values for first row
                var value = try rows[0][0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try rows[0][1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                value = try rows[0][2].getString() ?? ""
                #expect(value == "value3", "Third value in first row should be 'value3'")

                // Check values for second row
                let emptyValue = try rows[1][0].getString()
                #expect(emptyValue == nil, "First column in second row should be empty")
                value = try rows[1][1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try rows[1][2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")

                // Check values for third row
                value = try rows[2][0].getString() ?? ""
                #expect(value == "value1", "First value in third row should be 'value1'")
                value = try rows[2][1].getString() ?? ""
                #expect(value == "value2", "Second value in third row should be 'value2'")
                value = try rows[2][2].getString() ?? ""
                #expect(value == "value3", "Third value in third row should be 'value3'")
            }
        )
    }

    @Test("Empty value at middle of row")
    func testMiddleDelimiter() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value2", "value3"],
            ["value1", "", "value3"],
            ["value1", "value2", "value3"],
        ]

        try await TestUtils.runTest(
            testName: "Empty value at middle of row",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 3, "Should have 3 rows")

                // Check values for first row
                var value = try rows[0][0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try rows[0][1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                value = try rows[0][2].getString() ?? ""
                #expect(value == "value3", "Third value in first row should be 'value3'")

                // Check values for second row
                value = try rows[1][0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                let emptyValue = try rows[1][1].getString()
                #expect(emptyValue == nil, "Second column in second row should be empty")
                value = try rows[1][2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")

                // Check values for third row
                value = try rows[2][0].getString() ?? ""
                #expect(value == "value1", "First value in third row should be 'value1'")
                value = try rows[2][1].getString() ?? ""
                #expect(value == "value2", "Second value in third row should be 'value2'")
                value = try rows[2][2].getString() ?? ""
                #expect(value == "value3", "Third value in third row should be 'value3'")
            }
        )
    }

    @Test("Empty value at end of row")
    func testTrailingDelimiter() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value2", ""],
            ["value1", "value2", "value3"],
        ]

        try await TestUtils.runTest(
            testName: "Empty value at end of row",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 2, "Should have 2 rows")

                // Check values for first row
                var value = try rows[0][0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try rows[0][1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                let emptyValue = try rows[0][2].getString()
                #expect(emptyValue == nil, "Third column in first row should be empty")

                // Check values for second row
                value = try rows[1][0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try rows[1][1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try rows[1][2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")
            }
        )
    }

    @Test("Multiple empty values at beginning of row")
    func testMultipleFrontDelimiters() async throws {
        let headers = ["", "", "header2", "header3"]
        let rows = [
            ["", "", "", "value4"],
            ["value1", "value2", "value3", "value4"],
        ]

        try await TestUtils.runTest(
            testName: "Multiple empty values at beginning of row",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 2, "Should have 2 rows")

                // First row has 3 empty values at the beginning
                #expect(rows[0].count == 4, "First row should have 4 columns")
                let emptyValue = try rows[0][0].getString()
                #expect(emptyValue == nil, "First column in first row should be empty")
                let emptyValue2 = try rows[0][1].getString()
                #expect(emptyValue2 == nil, "Second column in first row should be empty")
                let emptyValue3 = try rows[0][2].getString()
                #expect(emptyValue3 == nil, "Third column in first row should be empty")
                var value = try rows[0][3].getString() ?? ""
                #expect(value == "value4", "Fourth value in first row should be 'value4'")

                // Second row with no empty values
                value = try rows[1][0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try rows[1][1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try rows[1][2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")
                value = try rows[1][3].getString() ?? ""
                #expect(value == "value4", "Fourth value in second row should be 'value4'")
            }
        )
    }

    @Test("Multiple empty values at end of row")
    func testMultipleTrailingDelimiters() async throws {
        let headers = ["header1", "header2", "", "", ""]
        let rows = [
            ["value1", "value2", "", "", ""],
            ["value1", "value2", "value3", "value4", "value5"],
        ]

        try await TestUtils.runTest(
            testName: "Multiple empty values at end of row",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 2, "Should have 2 rows")

                // First row has 3 empty values at the end
                #expect(rows[0].count == 5, "First row should have 5 columns")
                var value = try rows[0][0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try rows[0][1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                let emptyValue = try rows[0][2].getString()
                #expect(emptyValue == nil, "Third column in first row should be empty")
                let emptyValue2 = try rows[0][3].getString()
                #expect(emptyValue2 == nil, "Fourth column in first row should be empty")
                let emptyValue3 = try rows[0][4].getString()
                #expect(emptyValue3 == nil, "Fifth column in first row should be empty")

                // Second row with no empty values
                value = try rows[1][0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try rows[1][1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try rows[1][2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")
                value = try rows[1][3].getString() ?? ""
                #expect(value == "value4", "Fourth value in second row should be 'value4'")
                value = try rows[1][4].getString() ?? ""
                #expect(value == "value5", "Fifth value in second row should be 'value5'")
            }
        )
    }
}
