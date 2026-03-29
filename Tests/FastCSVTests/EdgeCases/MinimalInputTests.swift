@testable import FastCSV
import Foundation
import Testing

@Suite("Minimal Input Tests")
struct MinimalInputTests {
    // MARK: - Empty Files

    @Test("Empty file throws invalidFile error")
    func testEmptyFile() async throws {
        let url = try TestUtils.createRawCSVFile(content: "")

        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: CSVError.self) {
            _ = try FastCSV.makeArrayRows(fileURL: url)
        }
    }

    @Test("File with only a newline yields zero data rows")
    func testNewlineOnlyFile() async throws {
        let url = try TestUtils.createRawCSVFile(content: "\n")

        defer { try? FileManager.default.removeItem(at: url) }

        // The newline is consumed as a single empty header row, leaving no data rows
        let rows = try FastCSV.makeArrayRows(fileURL: url)
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0, "Newline-only file should yield 0 data rows")
    }

    @Test("File with only CRLF yields zero data rows")
    func testCRLFOnlyFile() async throws {
        let url = try TestUtils.createRawCSVFile(content: "\r\n")

        defer { try? FileManager.default.removeItem(at: url) }

        // The CRLF is consumed as a single empty header row, leaving no data rows
        let rows = try FastCSV.makeArrayRows(fileURL: url)
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0, "CRLF-only file should yield 0 data rows")
    }

    // MARK: - Header-Only Files

    @Test("Header-only file yields zero data rows (array)")
    func testHeaderOnlyArray() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age,city\n")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true)
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0, "Header-only file should yield 0 data rows")
    }

    @Test("Header-only file yields zero data rows (dictionary)")
    func testHeaderOnlyDictionary() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age,city\n")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true)
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0, "Header-only file should yield 0 data rows")
    }

    @Test("Header-only file without trailing newline yields zero data rows")
    func testHeaderOnlyNoTrailingNewline() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age,city")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true)
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0, "Header-only file (no trailing newline) should yield 0 data rows")
    }

    // MARK: - Single Data Row

    @Test("Single row with headers (array)")
    func testSingleRowWithHeadersArray() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age\nAlice,30\n")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1, "Should have exactly 1 data row")
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let name = try results[0].values[0].stringIfPresent()
        let age = try results[0].values[1].stringIfPresent()
        #expect(name == "Alice")
        #expect(age == "30")
    }

    @Test("Single row with headers (dictionary)")
    func testSingleRowWithHeadersDictionary() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age\nAlice,30\n")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1, "Should have exactly 1 data row")
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let name = try results[0].values["name"]?.stringIfPresent()
        let age = try results[0].values["age"]?.stringIfPresent()
        #expect(name == "Alice")
        #expect(age == "30")
    }

    @Test("Single row without headers")
    func testSingleRowNoHeaders() async throws {
        let url = try TestUtils.createRawCSVFile(content: "Alice,30\n")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: false)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1, "Should have exactly 1 data row")
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let val0 = try results[0].values[0].stringIfPresent()
        let val1 = try results[0].values[1].stringIfPresent()
        #expect(val0 == "Alice")
        #expect(val1 == "30")
    }

    @Test("Single row without trailing newline")
    func testSingleRowNoTrailingNewline() async throws {
        let url = try TestUtils.createRawCSVFile(content: "name,age\nAlice,30")

        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1, "Should have exactly 1 data row")
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let name = try results[0].values[0].stringIfPresent()
        #expect(name == "Alice")
    }
}
