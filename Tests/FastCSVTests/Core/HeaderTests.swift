@testable import FastCSV
import Foundation
import Testing

@Suite("Header Tests")
struct HeaderTests {
    @Test("Array with headers before parsing")
    func testHeaders() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        let tempURL = try TestUtils.createTemporaryCSVFile(
            headers: headers,
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = try FastCSV(
            fileURL: tempURL,
        )

        let resultHeaders = parser.headers

        #expect(resultHeaders.count == 3, "Should have 3 headers")
        #expect(resultHeaders[0] == "header1", "First header should be 'header1'")
        #expect(resultHeaders[1] == "header2", "Second header should be 'header2'")
        #expect(resultHeaders[2] == "header3", "Third header should be 'header3'")
    }

    @Test("Headers after parsing")
    func testHeadersAfterParsing() async throws {
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        let tempURL = try TestUtils.createTemporaryCSVFile(
            headers: headers,
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = try FastCSV(
            fileURL: tempURL,
            hasHeaders: true
        )

        var iterator = try parser.makeValueArrayIterator()

        while let _ = iterator.next() {}

        let resultHeaders = parser.headers

        #expect(resultHeaders.count == 3, "Should have 3 headers")
        #expect(resultHeaders[0] == "header1", "First header should be 'header1'")
        #expect(resultHeaders[1] == "header2", "Second header should be 'header2'")
        #expect(resultHeaders[2] == "header3", "Third header should be 'header3'")
    }

    @Test("Array with headers and custom headers")
    func testArrayHeadersWithCustomHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Headers with custom headers",
            contentHeaders: headers,
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .array,
            validate: { (rows: [[CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
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

    @Test("Dictionary with headers and custom headers")
    func testDictionaryHeadersWithCustomHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let headers = ["header1", "header2", "header3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Headers with custom headers",
            contentHeaders: headers,
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0]["custom1"]?.getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")

                let value2 = try rows[0]["custom2"]?.getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0]["custom3"]?.getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")

                #expect(rows[0]["header1"] == nil, "Header 'header1' should not exist")
                #expect(rows[0]["header2"] == nil, "Header 'header2' should not exist")
                #expect(rows[0]["header3"] == nil, "Header 'header3' should not exist")
            }
        )
    }

    @Test("Dictionary with custom headers and no headers")
    func testHeadersWithCustomHeadersAndNoHeaders() async throws {
        let customHeaders = ["custom1", "custom2", "custom3"]
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Headers with custom headers and no headers in file",
            contentHeaders: [],
            contentRows: rows,
            customHeaders: customHeaders,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0]["custom1"]?.getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")

                let value2 = try rows[0]["custom2"]?.getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0]["custom3"]?.getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")

                #expect(rows[0]["value1"] == nil, "Header 'value1' should not exist")
                #expect(rows[0]["value2"] == nil, "Header 'value2' should not exist")
                #expect(rows[0]["value2"] == nil, "Header 'value3' should not exist")
            }
        )
    }

    @Test("Dictionary without headers")
    func testEmptyHeaders() async throws {
        let rows = [["value1", "value2", "value3"]]

        try await TestUtils.runTest(
            testName: "Empty headers",
            contentRows: rows,
            outputFormat: .dictionary,
            validate: { (rows: [[String: CSVValue]]) in
                #expect(rows.count == 1, "Should have 1 row")
                #expect(rows[0].count == 3, "First row should have 3 columns")

                let value1 = try rows[0]["column_1"]?.getString() ?? ""
                #expect(value1 == "value1", "First value should be 'value1'")

                let value2 = try rows[0]["column_2"]?.getString() ?? ""
                #expect(value2 == "value2", "Second value should be 'value2'")

                let value3 = try rows[0]["column_3"]?.getString() ?? ""
                #expect(value3 == "value3", "Third value should be 'value3'")
            }
        )
    }
}
