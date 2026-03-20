@testable import FastCSV
import Foundation
import Testing

@Suite("Dictionary Iterator Tests")
struct DictionaryIteratorTests {
    @Test("Dictionary access in CSVDictionaryResult")
    func testDictionaryIteratorWithHeaders() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Dictionary Iterator with headers before parsing",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (results: [CSVDictionaryResult]) in
                #expect(TestUtils.isErrorFree(dictionaryResult: results), "All rows should be error-free")
                for result in results {
                    #expect(result.count == 3, "Should have 3 columns")
                    #expect(result.error == nil, "Should not have an error")

                    let expectedValue1 = "row1_col1"
                    let value1 = try result["header1"]?.getString() ?? ""
                    #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                    let expectedValue2 = "row1_col2"
                    let value2 = try result["header2"]?.getString() ?? ""
                    #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                    let expectedValue3 = "row1_col3"
                    let value3 = try result["header3"]?.getString() ?? ""
                    #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
                }
            }
        )
    }
}
