@testable import FastCSV
import Foundation
import Testing

@Suite("Array Iterator Tests")
struct ArrayIteratorTests {
    @Test("Array Iterator with headers")
    func testArrayIteratorWithHeaders() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Array Iterator with headers before parsing",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
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
}
