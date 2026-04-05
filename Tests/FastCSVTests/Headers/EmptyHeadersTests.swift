@testable import FastCSV
import Foundation
import Testing

struct EmptyHeadersTests {
    @Test
    func `Dictionary without headers`() async throws {
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Empty headers",
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")

                let expectedValue1 = "row1_col1"
                let value1 = try results[0].values["column_1"]?.stringIfPresent() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values["column_2"]?.stringIfPresent() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values["column_3"]?.stringIfPresent() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            },
        )
    }

    @Test
    func `Dictionary with empty values`() async throws {
        let headers = ["header1", "", "header3"]
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Empty headers with custom headers",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")

                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")

                let value1 = try results[0].values["header1"]?.stringIfPresent() ?? ""
                #expect(value1 == "row1_col1", "First value should be 'row1_col1'")

                let value2 = try results[0].values["column_2"]?.stringIfPresent() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")

                let value3 = try results[0].values["header3"]?.stringIfPresent() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")
            },
        )
    }
}
