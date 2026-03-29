@testable import FastCSV
import Foundation
import Testing

// MARK: - Test Types

private struct Person: Decodable, Equatable {
    let name: String
    let age: Int
}

private struct PersonWithOptional: Decodable, Equatable {
    let name: String
    let age: Int?
}

private struct PersonSubset: Decodable, Equatable {
    let name: String
}

private struct TypeRich: Decodable, Equatable {
    let str: String
    let integer: Int
    let dbl: Double
    let flt: Float
    let flag: Bool
}

private struct WithDecimal: Decodable, Equatable {
    let name: String
    let price: Decimal
}

// MARK: - Tests

@Suite("Decodable Support")
struct CSVDecodableTests {

    @Test("Basic decoding")
    func basicDecoding() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"], ["Bob", "25"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test("Column subset — extra CSV columns are ignored")
    func columnSubset() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age", "city"],
            rows: [["Alice", "30", "Boston"], ["Bob", "25", "NYC"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(PersonSubset.self, from: fileURL)
        var results: [PersonSubset] = []
        try people.forEach { results.append($0) }

        #expect(results == [PersonSubset(name: "Alice"), PersonSubset(name: "Bob")])
    }

    @Test("Optional field with empty value decodes as nil")
    func optionalEmptyValue() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "name,age\nAlice,\nBob,25\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(PersonWithOptional.self, from: fileURL)
        var results: [PersonWithOptional] = []
        try people.forEach { results.append($0) }

        #expect(results[0] == PersonWithOptional(name: "Alice", age: nil))
        #expect(results[1] == PersonWithOptional(name: "Bob", age: 25))
    }

    @Test("Schema mismatch — missing column throws keyNotFound")
    func schemaMismatch() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "city"],
            rows: [["Alice", "Boston"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    @Test("Type conversion failure throws")
    func typeConversionFailure() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "abc"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: (any Error).self) {
            try result.get()
        }
    }

    @Test("Custom headers with no header row")
    func customHeaders() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "Alice,30\nBob,25\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(
            Person.self,
            from: fileURL,
            hasHeaders: false,
            headers: ["name", "age"]
        )
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test("TSV config")
    func tsvConfig() throws {
        let tsvConfig = CSVParserConfig(delimiter: Delimiter(field: UInt8(ascii: "\t")))
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"]],
            config: tsvConfig
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL, config: tsvConfig)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }

    @Test("Empty file throws")
    func emptyFile() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: CSVError.self) {
            try FastCSV.makeRows(Person.self, from: fileURL)
        }
    }

    @Test("Bool decoding — true/false/yes/no/1/0")
    func boolDecoding() throws {
        struct Flags: Decodable, Equatable {
            let flag: Bool
        }

        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["flag"],
            rows: [["true"], ["false"], ["yes"], ["no"], ["1"], ["0"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var flags = try FastCSV.makeRows(Flags.self, from: fileURL)
        var results: [Bool] = []
        try flags.forEach { results.append($0.flag) }

        #expect(results == [true, false, true, false, true, false])
    }

    @Test("Multiple rows iterate lazily")
    func multipleRows() throws {
        let rows = (1...100).map { ["person_\($0)", "\($0)"] }
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: rows
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        var count = 0
        try people.forEach { _ in count += 1 }

        #expect(count == 100)
    }

    @Test("Quoted string fields are unquoted")
    func quotedStrings() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "name,age\n\"Alice, Jr.\",30\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results[0].name == "Alice, Jr.")
    }

    @Test("Multiple types decode correctly")
    func multipleTypes() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["str", "integer", "dbl", "flt", "flag"],
            rows: [["hello", "42", "3.14", "2.5", "true"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var items = try FastCSV.makeRows(TypeRich.self, from: fileURL)
        var results: [TypeRich] = []
        try items.forEach { results.append($0) }

        #expect(results[0].str == "hello")
        #expect(results[0].integer == 42)
        #expect(results[0].dbl == 3.14)
        #expect(results[0].flt == 2.5)
        #expect(results[0].flag == true)
    }

    @Test("Decimal decoding")
    func decimalDecoding() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "price"],
            rows: [["Widget", "19.99"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var items = try FastCSV.makeRows(WithDecimal.self, from: fileURL)
        var results: [WithDecimal] = []
        try items.forEach { results.append($0) }

        #expect(results[0].price == Decimal(string: "19.99"))
    }

    @Test("for-in with Result pattern works")
    func forInWithResult() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let people = try FastCSV.makeRows(Person.self, from: fileURL)
        for result in people {
            let person = try result.get()
            #expect(person == Person(name: "Alice", age: 30))
        }
    }

    @Test("Non-optional empty field throws valueNotFound")
    func nonOptionalEmptyField() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "name,age\n,30\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL)
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    @Test("Path string overload works")
    func pathStringOverload() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, from: fileURL.path)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }
}
