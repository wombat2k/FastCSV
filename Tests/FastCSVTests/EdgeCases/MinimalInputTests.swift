@testable import FastCSV
import Foundation
import Testing

@Suite("Minimal Input Tests")
struct MinimalInputTests {
    // MARK: - Empty Input

    @Test("Empty string throws")
    func testEmptyString() throws {
        #expect(throws: CSVError.self) {
            _ = try FastCSV.makeArrayRows(fromString: "")
        }
    }

    @Test("String with only a newline yields zero data rows")
    func testNewlineOnly() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\n")
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0)
    }

    @Test("String with only CRLF yields zero data rows")
    func testCRLFOnly() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\r\n")
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0)
    }

    // MARK: - Header-Only

    @Test("Header-only yields zero data rows (array)")
    func testHeaderOnlyArray() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0)
    }

    @Test("Header-only yields zero data rows (dictionary)")
    func testHeaderOnlyDictionary() throws {
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0)
    }

    @Test("Header-only without trailing newline yields zero data rows")
    func testHeaderOnlyNoTrailingNewline() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city")
        var count = 0
        for _ in rows { count += 1 }
        #expect(count == 0)
    }

    // MARK: - Single Data Row

    @Test("Single row with headers (array)")
    func testSingleRowWithHeadersArray() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age\nAlice,30\n")
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].stringIfPresent() == "Alice")
        #expect(try results[0].values[1].stringIfPresent() == "30")
    }

    @Test("Single row with headers (dictionary)")
    func testSingleRowWithHeadersDictionary() throws {
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,age\nAlice,30\n")
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["name"]?.stringIfPresent() == "Alice")
        #expect(try results[0].values["age"]?.stringIfPresent() == "30")
    }

    @Test("Single row without headers")
    func testSingleRowNoHeaders() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "Alice,30\n", hasHeaders: false)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].stringIfPresent() == "Alice")
        #expect(try results[0].values[1].stringIfPresent() == "30")
    }

    @Test("Single row without trailing newline")
    func testSingleRowNoTrailingNewline() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age\nAlice,30")
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].stringIfPresent() == "Alice")
    }
}
