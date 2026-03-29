@testable import FastCSV
import Foundation
import Testing

@Suite("Custom Headers Tests")
struct CustomHeadersTests {
    @Test("Array with headers and custom headers")
    func testArrayHeadersWithCustomHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Headers with custom headers",
            contentHeaders: headers,
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let expectedValue1 = "row1_col1"
                let value1 = try results[0].values[0].stringIfPresent() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values[1].stringIfPresent() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values[2].stringIfPresent() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            }
        )
    }

    @Test("Dictionary with headers and custom headers")
    func testDictionaryHeadersWithCustomHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Headers with custom headers",
            contentHeaders: headers,
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")
                #expect(results[0].error == nil, "First row should not have an error")

                let value1 = try results[0].values["custom1"]?.stringIfPresent() ?? ""
                #expect(value1 == "row1_col1", "First value should be 'row1_col1'")

                let value2 = try results[0].values["custom2"]?.stringIfPresent() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")

                let value3 = try results[0].values["custom3"]?.stringIfPresent() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")

                #expect(results[0].values["header1"] == nil, "Header 'header1' should not exist")
                #expect(results[0].values["header2"] == nil, "Header 'header2' should not exist")
                #expect(results[0].values["header3"] == nil, "Header 'header3' should not exist")
            }
        )
    }

    @Test("Dictionary with custom headers and no headers")
    func testHeadersWithCustomHeadersAndNoHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Headers with custom headers and no headers in file",
            contentHeaders: [],
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")

                let value1 = try results[0].values["custom1"]?.stringIfPresent() ?? ""
                #expect(value1 == "row1_col1", "First value should be 'row1_col1'")

                let value2 = try results[0].values["custom2"]?.stringIfPresent() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")

                let value3 = try results[0].values["custom3"]?.stringIfPresent() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")

                #expect(results[0].values["row1_col1"] == nil, "Header 'value1' should not exist")
                #expect(results[0].values["row1_col2"] == nil, "Header 'value2' should not exist")
                #expect(results[0].values["row1_col3"] == nil, "Header 'value3' should not exist")
            }
        )
    }
}
