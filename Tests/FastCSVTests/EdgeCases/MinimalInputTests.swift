@testable import FastCSV
import Foundation
import Testing

struct MinimalInputTests {
    // MARK: - Empty Input

    @Test("Empty string throws")
    func emptyString() throws {
        #expect(throws: CSVError.self) {
            _ = try FastCSV.makeArrayRows(fromString: "")
        }
    }

    @Test("String with only a newline yields zero data rows")
    func newlineOnly() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("String with only CRLF yields zero data rows")
    func cRLFOnly() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\r\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    // MARK: - Header-Only

    @Test("Header-only yields zero data rows (array)")
    func headerOnlyArray() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("Header-only yields zero data rows (dictionary)")
    func headerOnlyDictionary() throws {
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("Header-only without trailing newline yields zero data rows")
    func headerOnlyNoTrailingNewline() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    // MARK: - Single Data Row

    @Test("Single row with headers (array)")
    func singleRowWithHeadersArray() throws {
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
    func singleRowWithHeadersDictionary() throws {
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
    func singleRowNoHeaders() throws {
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
    func singleRowNoTrailingNewline() throws {
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
