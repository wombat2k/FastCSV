@testable import FastCSV
import Foundation
import Testing

private struct Person: Decodable, Equatable {
    let name: String
    let age: Int
}

struct StringInputTests {
    // MARK: - String Input

    @Test
    func `Array rows from string`() throws {
        let rows = try FastCSV.makeArrayRows(fromString: "name,age\nAlice,30\nBob,25\n")
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 2)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].string == "Alice")
        #expect(try results[1].values[0].string == "Bob")
    }

    @Test
    func `Dictionary rows from string`() throws {
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,age\nAlice,30\n")
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(try results[0].values["name"]?.string == "Alice")
        #expect(try results[0].values["age"]?.string == "30")
    }

    @Test
    func `Decodable rows from string`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,30\nBob,25\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test
    func `String input with custom headers`() throws {
        var people = try FastCSV.makeRows(
            Person.self,
            fromString: "Alice,30\nBob,25\n",
            hasHeaders: false,
            headers: ["name", "age"],
        )
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test
    func `String input with quoted fields`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\n\"Alice, Jr.\",30\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results[0].name == "Alice, Jr.")
    }

    @Test
    func `Empty string throws`() throws {
        #expect(throws: CSVError.self) {
            try FastCSV.makeArrayRows(fromString: "")
        }
    }

    // MARK: - Data Input

    @Test
    func `Array rows from data`() throws {
        let data = Data("name,age\nAlice,30\n".utf8)
        let rows = try FastCSV.makeArrayRows(fromData: data)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(try results[0].values[0].string == "Alice")
        #expect(try results[0].values[1].string == "30")
    }

    @Test
    func `Decodable rows from data`() throws {
        let data = Data("name,age\nAlice,30\nBob,25\n".utf8)
        var people = try FastCSV.makeRows(Person.self, fromData: data)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test
    func `Empty data throws`() throws {
        #expect(throws: CSVError.self) {
            try FastCSV.makeArrayRows(fromData: Data())
        }
    }

    // MARK: - TSV from String

    @Test
    func `TSV from string`() throws {
        let tsvConfig = CSVParserConfig(delimiter: Delimiter(field: UInt8(ascii: "\t")))
        var people = try FastCSV.makeRows(
            Person.self,
            fromString: "name\tage\nAlice\t30\n",
            config: tsvConfig,
        )
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }
}
