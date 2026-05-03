@testable import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif
import Testing

// MARK: - Test Types

private struct Person: Codable, Equatable {
    let name: String
    let age: Int
    let score: Double
}

private struct Employee: Codable, Equatable {
    let name: String
    let active: Bool
    let salary: Decimal
}

private struct WithOptional: Codable, Equatable {
    let name: String
    let nickname: String?
}

private struct WithDate: Codable, Equatable {
    let name: String
    let startDate: Date
}

// MARK: - String Array Writing

struct CSVWriterTests {
    @Test
    func `Write string array rows with headers`() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30", "95.5"], ["Bob", "25", "87.3"]],
            headers: ["name", "age", "score"],
        )
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test
    func `Write string array rows without headers`() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30"], ["Bob", "25"]],
        )
        #expect(csv == "Alice,30\nBob,25\n")
    }

    @Test
    func `Write empty rows with headers`() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["name", "age"])
        let csv = try #require(writer.toString())
        #expect(csv == "name,age\n")
    }

    @Test
    func `Write empty Encodable array produces empty string`() throws {
        let csv = try FastCSV.writeString([Person]())
        #expect(csv == "")
    }

    // MARK: - Quoting

    @Test
    func `Field containing delimiter is quoted`() throws {
        let csv = try FastCSV.writeString(
            [["Alice, Jr.", "30"]],
            headers: ["name", "age"],
        )
        #expect(csv == "name,age\n\"Alice, Jr.\",30\n")
    }

    @Test
    func `Field containing quote is quoted and escaped`() throws {
        let csv = try FastCSV.writeString(
            [["She said \"hello\"", "30"]],
            headers: ["name", "age"],
        )
        #expect(csv == "name,age\n\"She said \"\"hello\"\"\",30\n")
    }

    @Test
    func `Field containing newline is quoted`() throws {
        let csv = try FastCSV.writeString(
            [["line1\nline2", "30"]],
            headers: ["name", "age"],
        )
        #expect(csv == "name,age\n\"line1\nline2\",30\n")
    }

    @Test
    func `Field containing carriage return is quoted`() throws {
        let csv = try FastCSV.writeString(
            [["line1\rline2", "30"]],
        )
        #expect(csv == "\"line1\rline2\",30\n")
    }

    @Test
    func `Plain field is not quoted`() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30"]],
        )
        #expect(csv == "Alice,30\n")
    }

    // MARK: - Encodable Writing

    @Test
    func `Encodable rows with auto headers`() throws {
        let people = [
            Person(name: "Alice", age: 30, score: 95.5),
            Person(name: "Bob", age: 25, score: 87.3),
        ]
        let csv = try FastCSV.writeString(people)
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test
    func `Bool encoding as true/false`() throws {
        let employees = [
            Employee(name: "Alice", active: true, salary: 75000),
            Employee(name: "Bob", active: false, salary: 65000),
        ]
        let csv = try FastCSV.writeString(employees)
        #expect(csv.contains("true"))
        #expect(csv.contains("false"))
    }

    @Test
    func `Decimal encoding`() throws {
        let employees = try [
            Employee(name: "Alice", active: true, salary: #require(Decimal(string: "75000.50"))),
        ]
        let csv = try FastCSV.writeString(employees)
        #expect(csv.contains("75000.5"))
    }

    @Test
    func `Optional nil becomes empty field`() throws {
        let items = [
            WithOptional(name: "Alice", nickname: nil),
            WithOptional(name: "Bob", nickname: "Bobby"),
        ]
        let csv = try FastCSV.writeString(items)
        #expect(csv == "name,nickname\nAlice,\nBob,Bobby\n")
    }

    @Test
    func `Optional with value encodes normally`() throws {
        let items = [WithOptional(name: "Alice", nickname: "Ali")]
        let csv = try FastCSV.writeString(items)
        #expect(csv == "name,nickname\nAlice,Ali\n")
    }

    @Test
    func `Date encoding with default strategy`() throws {
        let strategy: CSVDateStrategy = .iso8601Date
        let date = try #require(try? strategy.parse("2026-03-15"))

        let items = [WithDate(name: "Alice", startDate: date)]
        let config = CSVWriterConfig(dateStrategy: strategy)
        let csv = try FastCSV.writeString(items, config: config)
        #expect(csv.contains("2026-03-15"))
    }

    // MARK: - Custom Delimiters

    @Test
    func `TSV output`() throws {
        let config = CSVWriterConfig(delimiter: CSVFormat.tsv.delimiter)
        let csv = try FastCSV.writeString(
            [["Alice", "30"], ["Bob", "25"]],
            headers: ["name", "age"],
            config: config,
        )
        #expect(csv == "name\tage\nAlice\t30\nBob\t25\n")
    }

    @Test
    func `TSV with embedded commas not quoted`() throws {
        let config = CSVWriterConfig(delimiter: CSVFormat.tsv.delimiter)
        let csv = try FastCSV.writeString(
            [["Alice, Jr.", "30"]],
            config: config,
        )
        // Commas don't need quoting in TSV — only tabs would
        #expect(csv == "Alice, Jr.\t30\n")
    }

    // MARK: - CSVWriter Class

    @Test
    func `CSVWriter row-by-row writing`() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["a", "b"])
        try writer.writeRow(["1", "2"])
        try writer.writeRow(["3", "4"])
        let csv = try #require(writer.toString())
        #expect(csv == "a,b\n1,2\n3,4\n")
    }

    @Test
    func `CSVWriter Encodable row-by-row`() throws {
        let writer = CSVWriter()
        try writer.writeRow(Person(name: "Alice", age: 30, score: 95.5))
        try writer.writeRow(Person(name: "Bob", age: 25, score: 87.3))
        let csv = try #require(writer.toString())
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test
    func `Headers written twice throws`() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["a", "b"])
        #expect(throws: CSVError.self) {
            try writer.writeHeaders(["c", "d"])
        }
    }

    // MARK: - File Output

    @Test
    func `Write to file and read back`() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_write_\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }

        let people = [
            Person(name: "Alice", age: 30, score: 95.5),
            Person(name: "Bob", age: 25, score: 87.3),
        ]
        try FastCSV.writeRows(people, toURL: url)

        // Read it back
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    // MARK: - Round-Trip

    @Test
    func `Full round-trip: write → read → compare`() throws {
        let original = [
            Person(name: "Alice", age: 30, score: 95.5),
            Person(name: "Bob", age: 25, score: 87.3),
            Person(name: "Charlie", age: 35, score: 92.1),
        ]

        // Write to string
        let csv = try FastCSV.writeString(original)

        // Read back via Decodable
        let rows = try FastCSV.makeRows(Person.self, fromString: csv)
        var decoded: [Person] = []
        for result in rows {
            switch result {
            case let .success(person):
                decoded.append(person)
            case let .failure(error):
                throw error
            }
        }

        #expect(decoded == original)
    }

    @Test
    func `Round-trip with quoting: commas in fields survive`() throws {
        let original = [
            Person(name: "Smith, Alice", age: 30, score: 95.5),
        ]

        let csv = try FastCSV.writeString(original)
        #expect(csv.contains("\"Smith, Alice\""))

        let rows = try FastCSV.makeRows(Person.self, fromString: csv)
        var decoded: [Person] = []
        for result in rows {
            switch result {
            case let .success(person):
                decoded.append(person)
            case let .failure(error):
                throw error
            }
        }

        #expect(decoded == original)
    }

    @Test
    func `Round-trip with optional nil`() throws {
        let original = [
            WithOptional(name: "Alice", nickname: nil),
            WithOptional(name: "Bob", nickname: "Bobby"),
        ]

        let csv = try FastCSV.writeString(original)

        let rows = try FastCSV.makeRows(WithOptional.self, fromString: csv)
        var decoded: [WithOptional] = []
        for result in rows {
            switch result {
            case let .success(item):
                decoded.append(item)
            case let .failure(error):
                throw error
            }
        }

        #expect(decoded == original)
    }

    @Test
    func `Round-trip with bool`() throws {
        let original = [
            Employee(name: "Alice", active: true, salary: 75000),
            Employee(name: "Bob", active: false, salary: 65000),
        ]

        let csv = try FastCSV.writeString(original)

        let rows = try FastCSV.makeRows(Employee.self, fromString: csv)
        var decoded: [Employee] = []
        for result in rows {
            switch result {
            case let .success(item):
                decoded.append(item)
            case let .failure(error):
                throw error
            }
        }

        #expect(decoded == original)
    }

    @Test
    func `Round-trip with embedded quotes`() throws {
        let original = [
            Person(name: "She said \"hello\"", age: 30, score: 95.5),
        ]

        let csv = try FastCSV.writeString(original)
        let rows = try FastCSV.makeRows(Person.self, fromString: csv)
        var decoded: [Person] = []
        for result in rows {
            switch result {
            case let .success(person):
                decoded.append(person)
            case let .failure(error):
                throw error
            }
        }

        #expect(decoded == original)
    }
}
