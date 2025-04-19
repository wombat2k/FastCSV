@testable import FastCSV
import Foundation
import Testing

@Suite("Header Tests")
struct HeaderTests {
    @Test("Array with headers before parsing")
    func testHeaders() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        let tempURL = try TestUtils.createTemporaryCSVFile(
            headers: headers,
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = try FastCSV(
            fileURL: tempURL
        )

        let resultHeaders = parser.headers

        #expect(resultHeaders.count == 3, "Should have 3 headers")
        #expect(resultHeaders[0] == "header1", "First header should be 'header1'")
        #expect(resultHeaders[1] == "header2", "Second header should be 'header2'")
        #expect(resultHeaders[2] == "header3", "Third header should be 'header3'")
    }

    @Test("Headers after parsing")
    func testHeadersAfterParsing() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)

        let tempURL = try TestUtils.createTemporaryCSVFile(
            headers: headers,
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = try FastCSV(
            fileURL: tempURL,
            hasHeaders: true
        )

        var iterator = try parser.makeArrayIterator()

        var results: [CSVArrayResult] = []
        while let row = iterator.next() {
            results.append(row)
        }

        #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")

        let resultHeaders = parser.headers

        #expect(resultHeaders.count == 3, "Should have 3 headers")
        #expect(resultHeaders[0] == "header1", "First header should be 'header1'")
        #expect(resultHeaders[1] == "header2", "Second header should be 'header2'")
        #expect(resultHeaders[2] == "header3", "Third header should be 'header3'")
    }

    @Test("Headers with BOM")
    func testHeadersWithBOM() async throws {
        var headers = TestUtils.createHeaders(count: 3)
        let rows = TestUtils.createValues(rows: 1, columns: 3)
        headers[0] = "\u{FEFF}header1"

        let tempURL = try TestUtils.createTemporaryCSVFile(
            headers: headers,
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = try FastCSV(
            fileURL: tempURL,
            hasHeaders: true
        )

        var iterator = try parser.makeArrayIterator()

        var results: [CSVArrayResult] = []
        while let row = iterator.next() {
            results.append(row)
        }

        #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")

        let resultHeaders = parser.headers

        #expect(resultHeaders.count == 3, "Should have 3 headers")
        #expect(resultHeaders[0] == "header1", "First header should be 'header1'")
        #expect(resultHeaders[1] == "header2", "Second header should be 'header2'")
        #expect(resultHeaders[2] == "header3", "Third header should be 'header3'")
    }

    @Test("No headers, first row with BOM")
    func testNoHeadersWithBOM() async throws {
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][0] = "\u{FEFF}row1_col1"

        try await TestUtils.runTest(
            testName: "No headers with BOM",
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")

                let value1 = try results[0].values[0].getString() ?? ""
                #expect(value1 == "row1_col1", "First value should be 'row1_col1'")
            }
        )
    }
}
