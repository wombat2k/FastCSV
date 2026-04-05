@testable import FastCSV
import Foundation
import Testing

struct MinimalInputTests {
    // MARK: - Empty Input

    @Test
    func `Empty string throws`() throws {
        #expect(throws: CSVError.self) {
            _ = try FastCSV.makeArrayRows(fromString: "")
        }
    }

    @Test
    func `String with only a newline yields zero data rows`() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test
    func `String with only CRLF yields zero data rows`() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "\r\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    // MARK: - Header-Only

    @Test
    func `Header-only yields zero data rows (array)`() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test
    func `Header-only yields zero data rows (dictionary)`() throws {
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,age,city\n")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    @Test
    func `Header-only without trailing newline yields zero data rows`() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age,city")
        var count = 0
        for _ in rows {
            count += 1
        }
        #expect(count == 0)
    }

    // MARK: - Single Data Row

    @Test
    func `Single row with headers (array)`() throws {
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

    @Test
    func `Single row with headers (dictionary)`() throws {
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

    @Test
    func `Single row without headers`() throws {
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

    @Test
    func `Single row without trailing newline`() throws {
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
