@testable import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif
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

private struct WithDate: Decodable, Equatable {
    let name: String
    let startDate: Date
}

// MARK: - Tests

struct CSVDecodableTests {
    @Test
    func `Basic decoding`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,30\nBob,25\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test
    func `Column subset — extra CSV columns are ignored`() throws {
        var people = try FastCSV.makeRows(PersonSubset.self, fromString: "name,age,city\nAlice,30,Boston\nBob,25,NYC\n")
        var results: [PersonSubset] = []
        try people.forEach { results.append($0) }

        #expect(results == [PersonSubset(name: "Alice"), PersonSubset(name: "Bob")])
    }

    @Test
    func `Optional field with empty value decodes as nil`() throws {
        var people = try FastCSV.makeRows(PersonWithOptional.self, fromString: "name,age\nAlice,\nBob,25\n")
        var results: [PersonWithOptional] = []
        try people.forEach { results.append($0) }

        #expect(results[0] == PersonWithOptional(name: "Alice", age: nil))
        #expect(results[1] == PersonWithOptional(name: "Bob", age: 25))
    }

    @Test
    func `Schema mismatch — missing column throws keyNotFound`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,city\nAlice,Boston\n")
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    @Test
    func `Type conversion failure throws`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,abc\n")
        guard let result = people.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: (any Error).self) {
            try result.get()
        }
    }

    @Test
    func `Custom headers with no header row`() throws {
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
    func `TSV config`() throws {
        let tsvConfig = CSVParserConfig(delimiter: Delimiter(field: UInt8(ascii: "\t")))
        var people = try FastCSV.makeRows(Person.self, fromString: "name\tage\nAlice\t30\n", config: tsvConfig)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }

    @Test
    func `Empty string throws`() throws {
        #expect(throws: CSVError.self) {
            try FastCSV.makeRows(Person.self, fromString: "")
        }
    }

    @Test
    func `Bool decoding — true/false/yes/no/1/0`() throws {
        struct Flags: Decodable, Equatable {
            let flag: Bool
        }

        var flags = try FastCSV.makeRows(Flags.self, fromString: "flag\ntrue\nfalse\nyes\nno\n1\n0\n")
        var results: [Bool] = []
        try flags.forEach { results.append($0.flag) }

        #expect(results == [true, false, true, false, true, false])
    }

    @Test
    func `Multiple rows iterate lazily`() throws {
        let csv = "name,age\n" + (1 ... 100).map { "person_\($0),\($0)" }.joined(separator: "\n") + "\n"
        var people = try FastCSV.makeRows(Person.self, fromString: csv)
        var count = 0
        try people.forEach { _ in count += 1 }

        #expect(count == 100)
    }

    @Test
    func `Quoted string fields are unquoted`() throws {
        var people = try FastCSV.makeRows(Person.self, fromString: "name,age\n\"Alice, Jr.\",30\n")
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results[0].name == "Alice, Jr.")
    }

    @Test
    func `Multiple types decode correctly`() throws {
        var items = try FastCSV.makeRows(TypeRich.self, fromString: "str,integer,dbl,flt,flag\nhello,42,3.14,2.5,true\n")
        var results: [TypeRich] = []
        try items.forEach { results.append($0) }

        #expect(results[0].str == "hello")
        #expect(results[0].integer == 42)
        #expect(results[0].dbl == 3.14)
        #expect(results[0].flt == 2.5)
        #expect(results[0].flag == true)
    }

    @Test
    func `Decimal decoding`() throws {
        var items = try FastCSV.makeRows(WithDecimal.self, fromString: "name,price\nWidget,19.99\n")
        var results: [WithDecimal] = []
        try items.forEach { results.append($0) }

        #expect(results[0].price == Decimal(string: "19.99"))
    }

    @Test
    func `for-in with Result pattern works`() throws {
        let people = try FastCSV.makeRows(Person.self, fromString: "name,age\nAlice,30\n")
        for result in people {
            let person = try result.get()
            #expect(person == Person(name: "Alice", age: 30))
        }
    }

    @Test
    func `Non-optional empty field throws valueNotFound`() throws {
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

    @Test
    func `Path string overload works`() throws {
        let fileURL = try TestUtils.createTemporaryCSVFile(
            headers: ["name", "age"],
            rows: [["Alice", "30"]],
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var people = try FastCSV.makeRows(Person.self, fromPath: fileURL.path)
        var results: [Person] = []
        try people.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30)])
    }

    // MARK: - Quoted Numeric Fields

    @Test
    func `Quoted integers and doubles decode through Decodable`() throws {
        var rows = try FastCSV.makeRows(TypeRich.self, fromString: "str,integer,dbl,flt,flag\n\"hello\",\"42\",\"3.14\",\"2.5\",\"true\"\n")
        let result = try requireNext(&rows)
        #expect(result == TypeRich(str: "hello", integer: 42, dbl: 3.14, flt: 2.5, flag: true))
    }

    @Test
    func `Quoted Int8 decodes through integer width path`() throws {
        var rows = try FastCSV.makeRows(Person.self, fromString: "name,age\n\"Alice\",\"30\"\n")
        let result = try requireNext(&rows)
        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test
    func `Quoted Decimal decodes correctly`() throws {
        var rows = try FastCSV.makeRows(WithDecimal.self, fromString: "name,price\n\"Widget\",\"19.99\"\n")
        let result = try requireNext(&rows)
        #expect(try result == WithDecimal(name: "Widget", price: #require(Decimal(string: "19.99"))))
    }

    // MARK: - Column Mapping

    @Test
    func `Column mapping renames headers to match struct properties`() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,Years Old\nAlice,30\nBob,25\n",
            columnMapping: ["Full Name": "name", "Years Old": "age"],
        )
        var results: [Person] = []
        try rows.forEach { results.append($0) }

        #expect(results == [Person(name: "Alice", age: 30), Person(name: "Bob", age: 25)])
    }

    @Test
    func `Column mapping — unmapped columns keep their original names`() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "name,Years Old\nAlice,30\n",
            columnMapping: ["Years Old": "age"],
        )
        let result = try requireNext(&rows)

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test
    func `Column mapping — unmapped extra columns are ignored`() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,Years Old,City\nAlice,30,Boston\n",
            columnMapping: ["Full Name": "name", "Years Old": "age"],
        )
        let result = try requireNext(&rows)

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test
    func `Column mapping — missing mapped column throws keyNotFound`() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "Full Name,city\nAlice,Boston\n",
            columnMapping: ["Full Name": "name"],
        )
        guard let result = rows.next() else {
            Issue.record("Expected a row")
            return
        }

        #expect(throws: DecodingError.self) {
            try result.get()
        }
    }

    @Test
    func `Column mapping with fromPath overload`() throws {
        let fileURL = try TestUtils.createRawCSVFile(content: "Full Name,Years Old\nAlice,30\n")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var rows = try FastCSV.makeRows(
            Person.self,
            fromPath: fileURL.path,
            columnMapping: ["Full Name": "name", "Years Old": "age"],
        )
        let result = try requireNext(&rows)

        #expect(result == Person(name: "Alice", age: 30))
    }

    @Test
    func `Column mapping with empty mapping behaves like no mapping`() throws {
        var rows = try FastCSV.makeRows(
            Person.self,
            fromString: "name,age\nAlice,30\n",
            columnMapping: [:],
        )
        let result = try requireNext(&rows)

        #expect(result == Person(name: "Alice", age: 30))
    }

    // MARK: - Date Decoding

    @Test
    func `Date decoding uses default ISO 8601 strategy`() throws {
        var rows = try FastCSV.makeRows(
            WithDate.self,
            fromString: "name,startDate\nAlice,2026-03-15\n",
        )
        let result = try requireNext(&rows)

        #expect(result.name == "Alice")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: result.startDate)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    @Test
    func `Date decoding honors config dateStrategy`() throws {
        let style = Date.VerbatimFormatStyle(
            format: "\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)",
            locale: .init(identifier: "en_US_POSIX"),
            timeZone: .gmt,
            calendar: .init(identifier: .gregorian),
        )
        let config = CSVParserConfig(dateStrategy: .formatStyle(style))

        var rows = try FastCSV.makeRows(
            WithDate.self,
            fromString: "name,startDate\nAlice,03/15/2026\n",
            config: config,
        )
        let result = try requireNext(&rows)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: result.startDate)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }
}
