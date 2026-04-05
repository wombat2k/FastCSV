@testable import FastCSV
import Foundation
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
    @Test("Write string array rows with headers")
    func writeStringArrayWithHeaders() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30", "95.5"], ["Bob", "25", "87.3"]],
            headers: ["name", "age", "score"]
        )
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test("Write string array rows without headers")
    func writeStringArrayNoHeaders() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30"], ["Bob", "25"]]
        )
        #expect(csv == "Alice,30\nBob,25\n")
    }

    @Test("Write empty rows with headers")
    func writeEmptyRowsWithHeaders() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["name", "age"])
        let csv = try #require(writer.toString())
        #expect(csv == "name,age\n")
    }

    @Test("Write empty Encodable array produces empty string")
    func writeEmptyEncodableArray() throws {
        let csv = try FastCSV.writeString([Person]())
        #expect(csv == "")
    }

    // MARK: - Quoting

    @Test("Field containing delimiter is quoted")
    func quoteFieldWithDelimiter() throws {
        let csv = try FastCSV.writeString(
            [["Alice, Jr.", "30"]],
            headers: ["name", "age"]
        )
        #expect(csv == "name,age\n\"Alice, Jr.\",30\n")
    }

    @Test("Field containing quote is quoted and escaped")
    func quoteFieldWithQuote() throws {
        let csv = try FastCSV.writeString(
            [["She said \"hello\"", "30"]],
            headers: ["name", "age"]
        )
        #expect(csv == "name,age\n\"She said \"\"hello\"\"\",30\n")
    }

    @Test("Field containing newline is quoted")
    func quoteFieldWithNewline() throws {
        let csv = try FastCSV.writeString(
            [["line1\nline2", "30"]],
            headers: ["name", "age"]
        )
        #expect(csv == "name,age\n\"line1\nline2\",30\n")
    }

    @Test("Field containing carriage return is quoted")
    func quoteFieldWithCR() throws {
        let csv = try FastCSV.writeString(
            [["line1\rline2", "30"]]
        )
        #expect(csv == "\"line1\rline2\",30\n")
    }

    @Test("Plain field is not quoted")
    func plainFieldNotQuoted() throws {
        let csv = try FastCSV.writeString(
            [["Alice", "30"]]
        )
        #expect(csv == "Alice,30\n")
    }

    // MARK: - Encodable Writing

    @Test("Encodable rows with auto headers")
    func encodableAutoHeaders() throws {
        let people = [
            Person(name: "Alice", age: 30, score: 95.5),
            Person(name: "Bob", age: 25, score: 87.3),
        ]
        let csv = try FastCSV.writeString(people)
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test("Bool encoding as true/false")
    func boolEncoding() throws {
        let employees = [
            Employee(name: "Alice", active: true, salary: 75000),
            Employee(name: "Bob", active: false, salary: 65000),
        ]
        let csv = try FastCSV.writeString(employees)
        #expect(csv.contains("true"))
        #expect(csv.contains("false"))
    }

    @Test("Decimal encoding")
    func decimalEncoding() throws {
        let employees = try [
            Employee(name: "Alice", active: true, salary: #require(Decimal(string: "75000.50"))),
        ]
        let csv = try FastCSV.writeString(employees)
        #expect(csv.contains("75000.5"))
    }

    @Test("Optional nil becomes empty field")
    func optionalNilEncoding() throws {
        let items = [
            WithOptional(name: "Alice", nickname: nil),
            WithOptional(name: "Bob", nickname: "Bobby"),
        ]
        let csv = try FastCSV.writeString(items)
        #expect(csv == "name,nickname\nAlice,\nBob,Bobby\n")
    }

    @Test("Optional with value encodes normally")
    func optionalValueEncoding() throws {
        let items = [WithOptional(name: "Alice", nickname: "Ali")]
        let csv = try FastCSV.writeString(items)
        #expect(csv == "name,nickname\nAlice,Ali\n")
    }

    @Test("Date encoding with default formatter")
    func dateDefaultFormatter() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = try #require(formatter.date(from: "2026-03-15"))

        let items = [WithDate(name: "Alice", startDate: date)]
        let config = CSVWriterConfig(dateFormatter: formatter)
        let csv = try FastCSV.writeString(items, config: config)
        #expect(csv.contains("2026-03-15"))
    }

    // MARK: - Custom Delimiters

    @Test("TSV output")
    func tsvOutput() throws {
        let config = CSVWriterConfig(delimiter: CSVFormat.tsv.delimiter)
        let csv = try FastCSV.writeString(
            [["Alice", "30"], ["Bob", "25"]],
            headers: ["name", "age"],
            config: config
        )
        #expect(csv == "name\tage\nAlice\t30\nBob\t25\n")
    }

    @Test("TSV with embedded commas not quoted")
    func tsvCommasNotQuoted() throws {
        let config = CSVWriterConfig(delimiter: CSVFormat.tsv.delimiter)
        let csv = try FastCSV.writeString(
            [["Alice, Jr.", "30"]],
            config: config
        )
        // Commas don't need quoting in TSV — only tabs would
        #expect(csv == "Alice, Jr.\t30\n")
    }

    // MARK: - CSVWriter Class

    @Test("CSVWriter row-by-row writing")
    func writerRowByRow() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["a", "b"])
        try writer.writeRow(["1", "2"])
        try writer.writeRow(["3", "4"])
        let csv = try #require(writer.toString())
        #expect(csv == "a,b\n1,2\n3,4\n")
    }

    @Test("CSVWriter Encodable row-by-row")
    func writerEncodableRowByRow() throws {
        let writer = CSVWriter()
        try writer.writeRow(Person(name: "Alice", age: 30, score: 95.5))
        try writer.writeRow(Person(name: "Bob", age: 25, score: 87.3))
        let csv = try #require(writer.toString())
        #expect(csv == "name,age,score\nAlice,30,95.5\nBob,25,87.3\n")
    }

    @Test("Headers written twice throws")
    func headersWrittenTwiceThrows() throws {
        let writer = CSVWriter()
        try writer.writeHeaders(["a", "b"])
        #expect(throws: CSVError.self) {
            try writer.writeHeaders(["c", "d"])
        }
    }

    // MARK: - File Output

    @Test("Write to file and read back")
    func writeToFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "test_write_\(UUID().uuidString).csv")
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

    @Test("Full round-trip: write → read → compare")
    func roundTrip() throws {
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

    @Test("Round-trip with quoting: commas in fields survive")
    func roundTripWithQuoting() throws {
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

    @Test("Round-trip with optional nil")
    func roundTripOptionalNil() throws {
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

    @Test("Round-trip with bool")
    func roundTripBool() throws {
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

    @Test("Round-trip with embedded quotes")
    func roundTripEmbeddedQuotes() throws {
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
