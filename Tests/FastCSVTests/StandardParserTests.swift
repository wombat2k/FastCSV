@testable import FastCSV
import Foundation
import Testing

@Suite("RFC 4180 Standard Parser Tests")
struct StandardParserTests {
    @Test("Basic CSV as array")
    func testBasicCSV() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value2", "value3"],
            ["value4", "value5", "value6"],
        ]

        try await TestUtils.runTest(
            testName: "Basic CSV",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 2, "Should have 2 rows")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0][0].getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")

                let value2 = try rows[0][1].getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0][2].getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")
            }
        )
    }

    @Test("Basic CSV as dictionary")
    func testBasicCSVAsDictionary() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Basic CSV as dictionary",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0]["header1"]?.getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")

                let value2 = try rows[0]["header2"]?.getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0]["header3"]?.getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")
            }
        )
    }

    @Test("Quoted fields")
    func testQuotedFields() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [["quoted value", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Quoted fields",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0][0].getString() ?? ""
                #expect(value1 == "quoted value", "First value should be 'quoted value'")

                let value2 = try rows[0][1].getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0][2].getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")
            }
        )
    }

    @Test("Escaped quotes")
    func testEscapedQuotes() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [[
            "value1",
            "value with \"escaped\" quotes",
            "value3",
        ]]

        try await TestUtils.runTest(
            testName: "Escaped quotes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 rows")
                #expect(rows[0].count == 3, "Second row should have 3 columns")

                let value = try rows[0][1].getString() ?? ""
                let expected = #"value with "escaped" quotes"#
                #expect(value == expected, "Second value should be '\(expected)'")
            }
        )
    }

    @Test("Return within quotes")
    func testReturnWithinQuotes() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [[
            "value1",
            "\"value with\nreturn\"",
            "value3",
        ]]

        try await TestUtils.runTest(
            testName: "Return within quotes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 rows")
                #expect(rows[0].count == 3, "Second row should have 3 columns")

                let value = try rows[0][1].getString() ?? ""
                #expect(value == "value with\nreturn", "Second value should be 'value with\nreturn'")
            }
        )
    }

    @Test("Empty fields")
    func testEmptyFields() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty fields",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                let value = try rows[0][1].getString()
                #expect(value == nil, "Second column in first row should be empty")
            }
        )
    }

    @Test("Empty headers in dictionaries")
    func testEmptyHeadersInDictionaries() async throws {
        let headers = ["header1", "", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty headers in dictionaries",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0]["header1"]?.getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")
                let value2 = try rows[0]["column_2"]?.getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")
                let value3 = try rows[0]["header3"]?.getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")
            }
        )
    }

    @Test("Unbalanced Row Throws")
    func testUnbalanceRowThrows() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [
            ["value1", "value2", "value3"],
            ["value4", "value5"],
        ]

        try await TestUtils.runTest(
            testName: "Unbalance row throws",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            expectThrow: CSVError.invalidCSV(message: "This should fail"),
            validate: { (_: [[CSVValue]]) in
                // No validation needed here, as we expect an error to be thrown
            }
        )
    }
}
