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
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values["column_1"]?.getString() ?? ""
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
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values["column_2"]?.getString() ?? ""
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
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].error == nil, "First row should not have an error")

                let value = try results[0].values["column_3"]?.getString() ?? ""
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
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 3, "Should have 3 rows")
                #expect(results[0].error == nil, "First row should not have an error")
                #expect(results[1].error == nil, "Second row should not have an error")
                #expect(results[2].error == nil, "Third row should not have an error")

                // Check values for first row
                var value = try results[0].values[0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try results[0].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                value = try results[0].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in first row should be 'value3'")

                // Check values for second row
                let emptyValue = try results[1].values[0].getString()
                #expect(emptyValue == nil, "First column in second row should be empty")
                value = try results[1].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try results[1].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")

                // Check values for third row
                value = try results[2].values[0].getString() ?? ""
                #expect(value == "value1", "First value in third row should be 'value1'")
                value = try results[2].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in third row should be 'value2'")
                value = try results[2].values[2].getString() ?? ""
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
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 3, "Should have 3 rows")

                // Check values for first row
                var value = try results[0].values[0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try results[0].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                value = try results[0].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in first row should be 'value3'")

                // Check values for second row
                value = try results[1].values[0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                let emptyValue = try results[1].values[1].getString()
                #expect(emptyValue == nil, "Second column in second row should be empty")
                value = try results[1].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")

                // Check values for third row
                value = try results[2].values[0].getString() ?? ""
                #expect(value == "value1", "First value in third row should be 'value1'")
                value = try results[2].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in third row should be 'value2'")
                value = try results[2].values[2].getString() ?? ""
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
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 2, "Should have 2 rows")

                // Check values for first row
                var value = try results[0].values[0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try results[0].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                let emptyValue = try results[0].values[2].getString()
                #expect(emptyValue == nil, "Third column in first row should be empty")

                // Check values for second row
                value = try results[1].values[0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try results[1].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try results[1].values[2].getString() ?? ""
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
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 2, "Should have 2 rows")

                // First row has 3 empty values at the beginning
                #expect(results[0].values.count == 4, "First row should have 4 columns")
                let emptyValue = try results[0].values[0].getString()
                #expect(emptyValue == nil, "First column in first row should be empty")
                let emptyValue2 = try results[0].values[1].getString()
                #expect(emptyValue2 == nil, "Second column in first row should be empty")
                let emptyValue3 = try results[0].values[2].getString()
                #expect(emptyValue3 == nil, "Third column in first row should be empty")
                var value = try results[0].values[3].getString() ?? ""
                #expect(value == "value4", "Fourth value in first row should be 'value4'")

                // Second row with no empty values
                value = try results[1].values[0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try results[1].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try results[1].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")
                value = try results[1].values[3].getString() ?? ""
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
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 2, "Should have 2 rows")

                // First row has 3 empty values at the end
                #expect(results[0].values.count == 5, "First row should have 5 columns")
                var value = try results[0].values[0].getString() ?? ""
                #expect(value == "value1", "First value in first row should be 'value1'")
                value = try results[0].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in first row should be 'value2'")
                let emptyValue = try results[0].values[2].getString()
                #expect(emptyValue == nil, "Third column in first row should be empty")
                let emptyValue2 = try results[0].values[3].getString()
                #expect(emptyValue2 == nil, "Fourth column in first row should be empty")
                let emptyValue3 = try results[0].values[4].getString()
                #expect(emptyValue3 == nil, "Fifth column in first row should be empty")

                // Second row with no empty values
                value = try results[1].values[0].getString() ?? ""
                #expect(value == "value1", "First value in second row should be 'value1'")
                value = try results[1].values[1].getString() ?? ""
                #expect(value == "value2", "Second value in second row should be 'value2'")
                value = try results[1].values[2].getString() ?? ""
                #expect(value == "value3", "Third value in second row should be 'value3'")
                value = try results[1].values[3].getString() ?? ""
                #expect(value == "value4", "Fourth value in second row should be 'value4'")
                value = try results[1].values[4].getString() ?? ""
                #expect(value == "value5", "Fifth value in second row should be 'value5'")
            }
        )
    }
}
