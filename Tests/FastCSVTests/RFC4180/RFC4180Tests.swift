@testable import FastCSV
import Foundation
import Testing

/// Tests for RFC 4180 conformance.
///
/// RFC 4180 defines the following rules:
/// 1. Records are delimited by line breaks (CRLF)
/// 2. The last record may or may not have a trailing line break
/// 3. An optional header line may appear as the first line
/// 4. Each line should contain the same number of fields
/// 5. Fields may be enclosed in double quotes
/// 6. Fields containing line breaks, double quotes, or commas must be enclosed in double quotes
/// 7. Double quotes inside fields are escaped by doubling them ("")
/// 8. Spaces are considered part of a field (not trimmed)
struct RFC4180Tests {
    /// Writes raw CSV bytes to a temp file, parses as array, returns safe-copied results.
    private func parseRawCSV(_ csv: String, hasHeaders: Bool = true) throws -> [CSVArrayResult] {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).csv")
        try csv.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let rows = try FastCSV.makeArrayRows(fromURL: tempURL, hasHeaders: hasHeaders)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }
        return results
    }

    // MARK: - Basic Record Parsing (Rules 1, 3, 4)

    @Test
    func `Basic CSV as array`() async throws {
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
                let value1 = try results[0].values[0].stringIfPresent() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values[1].stringIfPresent() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values[2].stringIfPresent() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            },
        )
    }

    @Test
    func `Basic CSV as dictionary`() async throws {
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
                let value1 = try results[0].values["header1"]?.stringIfPresent() ?? ""
                #expect(value1 == expectedValue1, "First value should be '\(expectedValue1)'")

                let expectedValue2 = "row1_col2"
                let value2 = try results[0].values["header2"]?.stringIfPresent() ?? ""
                #expect(value2 == expectedValue2, "Second value should be '\(expectedValue2)'")

                let expectedValue3 = "row1_col3"
                let value3 = try results[0].values["header3"]?.stringIfPresent() ?? ""
                #expect(value3 == expectedValue3, "Third value should be '\(expectedValue3)'")
            },
        )
    }

    // MARK: - Quoting (Rules 5, 6, 7)

    @Test
    func `Quoted fields`() async throws {
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

                let value1 = try results[0].values[0].stringIfPresent() ?? ""
                #expect(value1 == "quoted value", "First value should be 'quoted value'")

                let value2 = try results[0].values[1].stringIfPresent() ?? ""
                #expect(value2 == "row1_col2", "Second value should be 'row1_col2'")

                let value3 = try results[0].values[2].stringIfPresent() ?? ""
                #expect(value3 == "row1_col3", "Third value should be 'row1_col3'")
            },
        )
    }

    @Test
    func `Escaped quotes`() async throws {
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

                let value = try results[0].values[1].stringIfPresent() ?? ""
                let expected = #"value with "escaped" quotes"#
                #expect(value == expected, "Second value should be '\(expected)'")
            },
        )
    }

    @Test
    func `Newline within quoted field`() async throws {
        let headers = TestUtils.createHeaders(count: 3)
        var rows = TestUtils.createValues(rows: 1, columns: 3)
        rows[0][1] = "\"value with\nreturn\""

        try await TestUtils.runTest(
            testName: "Newline within quotes",
            contentHeaders: headers,
            contentRows: rows,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(TestUtils.isErrorFree(arrayResult: results), "All rows should be error-free")
                #expect(results.count == 1, "Should have 1 row")
                #expect(results[0].values.count == 3, "First row should have 3 columns")

                let value = try results[0].values[1].stringIfPresent() ?? ""
                #expect(value == "value with\nreturn", "Second value should be 'value with\\nreturn'")
            },
        )
    }

    // MARK: - Empty Fields

    // Empty field positions (leading, middle, trailing, multiple consecutive)
    // are thoroughly tested in Parsing/EmptyFieldTests.swift

    // MARK: - Empty Headers

    // Empty header auto-naming behavior is tested in Headers/EmptyHeadersTests.swift

    // MARK: - Line Endings (Rule 1)

    @Test
    func `Pure CRLF line endings`() throws {
        let csv = "header1,header2\r\n" +
            "value1,value2\r\n" +
            "value3,value4\r\n"

        let results = try parseRawCSV(csv)

        #expect(results.count == 2, "Should have 2 data rows")
        for result in results {
            #expect(result.error == nil)
            #expect(result.values.count == 2)
        }

        let v1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
        let v2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
        let v3 = try results[1].values[0].stringIfPresent() ?? "<nil>"
        let v4 = try results[1].values[1].stringIfPresent() ?? "<nil>"
        #expect(v1 == "value1")
        #expect(v2 == "value2")
        #expect(v3 == "value3")
        #expect(v4 == "value4")
    }

    @Test
    func `Mixed line endings (LF, CRLF)`() throws {
        let csv = "header1,header2,header3\n" + // LF
            "row1_col1,row1_col2,row1_col3\r\n" + // CRLF
            "row2_col1,row2_col2,row2_col3\n" + // LF
            "row3_col1,row3_col2,row3_col3\r\n" // CRLF

        let results = try parseRawCSV(csv)

        #expect(results.count == 3, "Should have 3 data rows")

        for (rowIndex, result) in results.enumerated() {
            #expect(result.error == nil, "Row \(rowIndex + 1) should not have an error")
            #expect(result.values.count == 3, "Row \(rowIndex + 1) should have 3 columns")

            for colIndex in 0 ..< 3 {
                let expected = "row\(rowIndex + 1)_col\(colIndex + 1)"
                let actual = try result.values[colIndex].stringIfPresent() ?? "<nil>"
                #expect(actual == expected)
            }
        }
    }

    // MARK: - Trailing Line Break Optional (Rule 2)

    @Test
    func `Last record without trailing line break`() throws {
        let csv = "header1,header2\n" +
            "value1,value2\n" +
            "value3,value4" // no trailing newline

        let results = try parseRawCSV(csv)

        #expect(results.count == 2, "Should have 2 data rows")
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let v3 = try results[1].values[0].stringIfPresent() ?? "<nil>"
        let v4 = try results[1].values[1].stringIfPresent() ?? "<nil>"
        #expect(v3 == "value3")
        #expect(v4 == "value4")
    }

    // MARK: - Comma Within Quoted Field (Rule 6)

    @Test
    func `Comma within quoted field`() throws {
        let csv = "header1,header2,header3\n" +
            "\"value1,with,commas\",normal,\"also,commas\"\n"

        let results = try parseRawCSV(csv)

        #expect(results.count == 1)
        #expect(results[0].error == nil)
        #expect(results[0].values.count == 3)

        let v1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
        let v2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
        let v3 = try results[0].values[2].stringIfPresent() ?? "<nil>"
        #expect(v1 == "value1,with,commas")
        #expect(v2 == "normal")
        #expect(v3 == "also,commas")
    }

    // MARK: - CRLF Within Quoted Field (Rule 6)

    @Test
    func `CRLF within quoted field`() throws {
        let csv = "header1,header2\r\n" +
            "\"line1\r\nline2\",normal\r\n"

        let results = try parseRawCSV(csv)

        #expect(results.count == 1)
        #expect(results[0].error == nil)
        #expect(results[0].values.count == 2)

        let v1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
        let v2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
        #expect(v1 == "line1\r\nline2")
        #expect(v2 == "normal")
    }

    // MARK: - Spaces Preserved (Rule 8)

    @Test
    func `Spaces are part of the field, not trimmed`() throws {
        let csv = "header1,header2,header3\n" +
            " leading,trailing ,\" quoted with spaces \"\n"

        let results = try parseRawCSV(csv)

        #expect(results.count == 1)
        #expect(results[0].error == nil)
        #expect(results[0].values.count == 3)

        let v1 = try results[0].values[0].stringIfPresent() ?? "<nil>"
        let v2 = try results[0].values[1].stringIfPresent() ?? "<nil>"
        let v3 = try results[0].values[2].stringIfPresent() ?? "<nil>"
        #expect(v1 == " leading", "Leading spaces should be preserved")
        #expect(v2 == "trailing ", "Trailing spaces should be preserved")
        #expect(v3 == " quoted with spaces ", "Spaces in quoted fields should be preserved")
    }
}
