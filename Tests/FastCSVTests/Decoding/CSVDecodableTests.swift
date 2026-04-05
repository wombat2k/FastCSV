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

struct CSVDecodableTests {
    @Test("Basic decoding")
    func basicDecoding() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,30\nBob,25\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test("Column subset — extra CSV columns are ignored")
    func columnSubset() throws {
        var people = try FastCSV.makeRows(PersonSubset.self, fromString: "name,age,city\nAlice,30,Boston\nBob,25,NYC\n")
        var results: [PersonSubset] = []
        try people.forEach { results.append($0) }

        #expect(results == [PersonSubset(name: "Alice"), PersonSubset(name: "Bob")])
    }

    @Test("Optional field with empty value decodes as nil")
    func optionalEmptyValue() throws {
        var people = try FastCSV.makeRows(PersonWithOptional.self, fromString: "name,age\nAlice,\nBob,25\n")
        var results: [PersonWithOptional] = []
        try people.forEach { results.append($0) }

        #expect(results[0] == PersonWithOptional(name: "Alice", age: nil))
        #expect(results[1] == PersonWithOptional(name: "Bob", age: 25))
    }

    @Test("Schema mismatch — missing column throws keyNotFound")
    func schemaMismatch() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,city\nAlice,Boston\n")
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
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,abc\n")
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
        var people = try FastCSV.makeRows(
            Person.self,
            fromString: "Alice,30\nBob,25\n",
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
        var people = try FastCSV.makeRows(Person.self, fromString: "name\tage\nAlice\t30\n", config: tsvConfig)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }

    @Test("Empty string throws")
    func emptyString() throws {
        #expect(throws: CSVError.self) {
            try FastCSV.makeRows(Person.self, fromString: "")
        }
    }

    @Test("Bool decoding — true/false/yes/no/1/0")
    func boolDecoding() throws {
        struct Flags: Decodable, Equatable {
            let flag: Bool
        }

        var flags = try FastCSV.makeRows(Flags.self, fromString: "flag\ntrue\nfalse\nyes\nno\n1\n0\n")
        var results: [Bool] = []
        try flags.forEach { results.append($0.flag) }

        #expect(results == [true, false, true, false, true, false])
    }

    @Test("Multiple rows iterate lazily")
    func multipleRows() throws {
        let csv = "name,age\n" + (1 ... 100).map { "person_\($0),\($0)" }.joined(separator: "\n") + "\n"
        var people = try FastCSV.makeRows(Person.self, fromString: csv)
        var count = 0
        try people.forEach { _ in count += 1 }

        #expect(count == 100)
    }

    @Test("Quoted string fields are unquoted")
    func quotedStrings() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\n\"Alice, Jr.\",30\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results[0].name == "Alice, Jr.")
    }

    @Test("Multiple types decode correctly")
    func multipleTypes() throws {
        var items = try FastCSV.makeRows(TypeRich.self, fromString: "str,integer,dbl,flt,flag\nhello,42,3.14,2.5,true\n")
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
        var items = try FastCSV.makeRows(WithDecimal.self, fromString: "name,price\nWidget,19.99\n")
        var results: [WithDecimal] = []
        try items.forEach { results.append($0) }

        #expect(results[0].price == Decimal(string: "19.99"))
    }

    @Test("for-in with Result pattern works")
    func forInWithResult() throws {
        let people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,30\n")
        for result in people {
            let person = try result.get()
            #expect(person == Person(name: "Alice", age: 30))
        }
    }

    @Test("Non-optional empty field throws valueNotFound")
    func nonOptionalEmptyField() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\n,30\n")
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    // MARK: - File I/O Overloads

    @Test("Path string overload works")
    func pathStringOverload() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"]]
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, fromPath: fileURL.path)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }

    // MARK: - Quoted Numeric Fields

    @Test("Quoted integers and doubles decode through Decodable")
    func quotedNumericDecoding() throws {
        var rows = try FastCSV.makeRows(TypeRich.self, fromString: "str,integer,dbl,flt,flag\n\"hello\",\"42\",\"3.14\",\"2.5\",\"true\"\n")
        let result = try #require(rows.next()?.get())
        #expect(result == TypeRich(str: "hello", integer: 42, dbl: 3.14, flt: 2.5, flag: true))
    }

    @Test("Quoted Int8 decodes through integer width path")
    func quotedInt8Decoding() throws {
        var rows = try FastCSV.makeRows(Person.self, fromString: "name,age\n\"Alice\",\"30\"\n")
        let result = try #require(rows.next()?.get())
        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test("Quoted Decimal decodes correctly")
    func quotedDecimalDecoding() throws {
        var rows = try FastCSV.makeRows(WithDecimal.self, fromString: "name,price\n\"Widget\",\"19.99\"\n")
        let result = try #require(rows.next()?.get())
        #expect(try result == WithDecimal(name: "Widget", price: #require(Decimal(string: "19.99"))))
    }

    // MARK: - Column Mapping

    @Test("Column mapping renames headers to match struct properties")
    func columnMappingBasic() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,Years Old\nAlice,30\nBob,25\n",
            columnMapping: ["Full Name": "name", "Years Old": "age"]
        )
        var results: [Person] = []
        try rows.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test("Column mapping — unmapped columns keep their original names")
    func columnMappingPartial() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "name,Years Old\nAlice,30\n",
            columnMapping: ["Years Old": "age"]
        )
        let result = try #require(rows.next()?.get())

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test("Column mapping — unmapped extra columns are ignored")
    func columnMappingExtraColumns() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,Years Old,City\nAlice,30,Boston\n",
            columnMapping: ["Full Name": "name", "Years Old": "age"]
        )
        let result = try #require(rows.next()?.get())

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test("Column mapping — missing mapped column throws keyNotFound")
    func columnMappingMissingColumn() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,city\nAlice,Boston\n",
            columnMapping: ["Full Name": "name"]
        )
        guard let result = rows.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    @Test("Column mapping with fromPath overload")
    func columnMappingFromPath() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "Full Name,Years Old\nAlice,30\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var rows = try FastCSV.makeRows(
            Person.self,
            fromPath: fileURL.path,
            columnMapping: ["Full Name": "name", "Years Old": "age"]
        )
        let result = try #require(rows.next()?.get())

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test("Column mapping with empty mapping behaves like no mapping")
    func columnMappingEmpty() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "name,age\nAlice,30\n",
            columnMapping: [:]
        )
        let result = try #require(rows.next()?.get())

        #expect(result == Person(name: "Alice", age: 30))
    }
}
