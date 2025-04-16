@testable import FastCSV
import Foundation
import Testing

@Suite("RFC 4180 Standard Parser Tests")
struct StandardParserTests {
    // MARK: - Basic Functionality Tests

    @Test("Basic CSV as array")
    func testBasicCSV() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 2, columns: 3)

        try await TestUtils.runTest(
            testName: "Basic CSV",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 2, "Should have 2 rows")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let expectedValue1 = "row1_col1"
                let value1 = try results[0].values[0].getString() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values[1].getString() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values[2].getString() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            }
        )
    }

    @Test("Basic CSV as dictionary")
    func testBasicCSVAsDictionary() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Basic CSV as dictionary",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let expectedValue1 = "row1_col1"
                let value1 = try results[0].values["header1"]?.getString() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values["header2"]?.getString() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values["header3"]?.getString() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            }
        )
    }

    // MARK: - Special Character Handling Tests

    @Test("Quoted fields")
    func testQuotedFields() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][0] = "\"quoted value\""

        try await TestUtils.runTest(
            testName: "Quoted fields",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let value1 = try results[0].values[0].getString() ?? ""
                #expect(value1 == "quoted value", "First value should be 'quoted value'")

                let value2 = try results[0].values[1].getString() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")

                let value3 = try results[0].values[2].getString() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")
            }
        )
    }

    @Test("Escaped quotes")
    func testEscapedQuotes() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][1] = #"value with "escaped" quotes"#

        try await TestUtils.runTest(
            testName: "Escaped quotes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 rows")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values[1].getString() ?? ""
                let expected = #"value with "escaped" quotes"#
                #expect(value == expected, "Second value should be '\(expected)'")
            }
        )
    }

    @Test("Return within quotes")
    func testReturnWithinQuotes() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][1] = "\"value with\nreturn\""

        try await TestUtils.runTest(
            testName: "Return within quotes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 rows")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values[1].getString() ?? ""
                #expect(value == "value with\nreturn", "Second value should be 'value with\nreturn'")
            }
        )
    }

    // MARK: - Empty Field Tests

    @Test("Empty fields")
    func testEmptyFields() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][1] = ""

        try await TestUtils.runTest(
            testName: "Empty fields",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values[1].getString()
                #expect(value == nil, "Second column in first row should be empty")
            }
        )
    }

    @Test("Empty headers in dictionaries")
    func testEmptyHeadersInDictionaries() async throws {
        var headers = TestUtils.createHeaders(count: 3)
        headers[1] = ""
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Empty headers in dictionaries",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let value1 = try results[0].values["header1"]?.getString() ?? ""
                #expect(value1 == "row1_col1", "First value should be 'row1_col1'")
                let value2 = try results[0].values["column_2"]?.getString() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")
                let value3 = try results[0].values["header3"]?.getString() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")
            }
        )
    }

    // MARK: - Performance Tests

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
