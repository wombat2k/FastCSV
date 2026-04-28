@testable import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif
import Testing

struct MemoryLifecycleTests {
    // MARK: - isSafe property

    @Test
    func `Values from iterator are unsafe (ref)`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            for value in row.values {
                #expect(!value.isSafe, "Iterator values should be .ref (unsafe)")
            }
        }
    }

    @Test
    func `Copied values are safe (own)`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let copied = row.values[0].copy()
            #expect(copied.isSafe, "Copied value should be .own (safe)")
        }
    }

    @Test
    func `Empty values are safe`() throws {
        let csv = "name,age\nAlice,\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let emptyValue = row.values[1]
            #expect(emptyValue.isEmpty)
            #expect(emptyValue.isSafe, "Empty values should be safe (.none)")
        }
    }

    // MARK: - copy() correctness

    @Test
    func `copy() preserves string value`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let original = try row.values[0].string
            let copied = try row.values[0].copy().string
            #expect(original == copied)
            #expect(original == "Alice")
        }
    }

    @Test
    func `copy() preserves numeric value`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let original = try row.values[1].int
            let copied = try row.values[1].copy().int
            #expect(original == copied)
            #expect(original == 30)
        }
    }

    @Test
    func `copy() on empty value stays empty`() throws {
        let csv = "name,age\nAlice,\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let copied = row.values[1].copy()
            #expect(copied.isEmpty)
            #expect(copied.isSafe)
        }
    }

    // MARK: - copyArray() / copyDictionary()

    @Test
    func `copyArray() produces all-safe values`() throws {
        let csv = "name,age,city\nAlice,30,Boston\nBob,25,NYC\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyArray()
            for value in safeCopy {
                #expect(value.isSafe, "All values from copyArray() should be safe")
            }
        }
    }

    @Test
    func `copyArray() preserves all values`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyArray()
            #expect(try safeCopy[0].string == "Alice")
            #expect(try safeCopy[1].int == 30)
        }
    }

    @Test
    func `copyDictionary() produces all-safe values`() throws {
        let csv = "name,age\nAlice,30\nBob,25\n"
        let rows = try FastCSV.makeDictionaryRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyDictionary()
            for (_, value) in safeCopy {
                #expect(value.isSafe, "All values from copyDictionary() should be safe")
            }
        }
    }

    @Test
    func `copyDictionary() preserves all values`() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeDictionaryRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyDictionary()
            #expect(try safeCopy["name"]?.string == "Alice")
            #expect(try safeCopy["age"]?.int == 30)
        }
    }

    // MARK: - Survival across iterations

    @Test
    func `Copied values survive across iterations`() throws {
        let csv = "name,age\nAlice,30\nBob,25\nCharlie,35\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        var savedValues: [CSVValue] = []

        for row in rows {
            savedValues.append(row.values[0].copy())
        }

        // Access saved values after iteration is complete — buffer is freed.
        #expect(savedValues.count == 3)
        #expect(try savedValues[0].string == "Alice")
        #expect(try savedValues[1].string == "Bob")
        #expect(try savedValues[2].string == "Charlie")
    }

    @Test
    func `Copied array results survive across iterations`() throws {
        let csv = "name,age\nAlice,30\nBob,25\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        var savedRows: [[CSVValue]] = []

        for row in rows {
            savedRows.append(row.copyArray())
        }

        #expect(savedRows.count == 2)
        #expect(try savedRows[0][0].string == "Alice")
        #expect(try savedRows[0][1].int == 30)
        #expect(try savedRows[1][0].string == "Bob")
        #expect(try savedRows[1][1].int == 25)
    }

    @Test
    func `Copied dictionary results survive across iterations`() throws {
        let csv = "name,age\nAlice,30\nBob,25\n"
        let rows = try FastCSV.makeDictionaryRows(fromString: csv)

        var savedRows: [[String: CSVValue]] = []

        for row in rows {
            savedRows.append(row.copyDictionary())
        }

        #expect(savedRows.count == 2)
        #expect(try savedRows[0]["name"]?.string == "Alice")
        #expect(try savedRows[1]["name"]?.string == "Bob")
    }

    // MARK: - Decodable path is inherently safe

    @Test
    func `Decodable values are owned strings, not buffer references`() throws {
        struct Person: Decodable, Equatable {
            let name: String
            let age: Int
        }

        let csv = "name,age\nAlice,30\nBob,25\nCharlie,35\n"
        var rows = try FastCSV.makeRows(Person.self, fromString: csv)

        var saved: [Person] = []
        try rows.forEach { saved.append($0) }

        // Decodable structs own their data — no copy needed.
        #expect(saved.count == 3)
        #expect(saved[0] == Person(name: "Alice", age: 30))
        #expect(saved[1] == Person(name: "Bob", age: 25))
        #expect(saved[2] == Person(name: "Charlie", age: 35))
    }
}
