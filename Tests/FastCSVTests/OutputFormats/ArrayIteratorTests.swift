@testable import FastCSV
import Foundation
import Testing

@Suite("Array Iterator Tests")
struct ArrayIteratorTests {
    @Test("Array Iterator with result accessors")
    func testArrayIteratorWithResultAccessors() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        try await TestUtils.runTest(
            testName: "Array Iterator with result accessors",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")

                for result in results {
                    #expect(result.values.count == 3, "Each row should have 3 columns")
                    #expect(result.error == nil, "Row should not have an error")
                    let value1 = try result[0].getString() ?? ""
                    #expect(value1 == "row1_col1", "First value should be 'row1_col1'")
                    let value2 = try result[1].getString() ?? ""
                    #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")
                    let value3 = try result[2].getString() ?? ""
                    #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")
                }
            }
        )
    }
}
