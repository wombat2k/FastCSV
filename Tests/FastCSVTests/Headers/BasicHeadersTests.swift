@testable import FastCSV
import Foundation
import Testing

@Suite("Header Tests")
struct HeaderTests {
    @Test("Array with headers before parsing")
    func testHeaders() throws {
        let csvRows = try FastCSV.makeDictionaryRows(fromString: "header1,header2,header3\nval1,val2,val3\n")

        let resultHeaders = csvRows.headers

        #expect(resultHeaders.count == 3)
        #expect(resultHeaders[0] == "header1")
        #expect(resultHeaders[1] == "header2")
        #expect(resultHeaders[2] == "header3")
    }

    @Test("Headers after parsing")
    func testHeadersAfterParsing() throws {
        let csvRows = try FastCSV.makeDictionaryRows(fromString: "header1,header2,header3\nval1,val2,val3\n")

        for _ in csvRows {}

        let resultHeaders = csvRows.headers

        #expect(resultHeaders.count == 3)
        #expect(resultHeaders[0] == "header1")
        #expect(resultHeaders[1] == "header2")
        #expect(resultHeaders[2] == "header3")
    }

    @Test("Headers with BOM")
    func testHeadersWithBOM() throws {
        let csvRows = try FastCSV.makeDictionaryRows(fromString: "\u{FEFF}header1,header2,header3\nval1,val2,val3\n")

        let resultHeaders = csvRows.headers

        #expect(resultHeaders.count == 3)
        #expect(resultHeaders[0] == "header1")
        #expect(resultHeaders[1] == "header2")
        #expect(resultHeaders[2] == "header3")
    }

    @Test("No headers, first row with BOM")
    func testNoHeadersWithBOM() throws {
        let rows = try FastCSV.makeArrayRows(
            fromString: "\u{FEFF}row1_col1,row1_col2,row1_col3\n",
            hasHeaders: false,
            headers: ["h1", "h2", "h3"]
        )

        var results: [CSVArrayResult] = []
        for row in rows { results.append(row) }

        #expect(results.count == 1)
        #expect(results[0].values.count == 3)
        let value1 = try results[0].values[0].stringIfPresent() ?? ""
        #expect(value1 == "row1_col1")
    }
}
