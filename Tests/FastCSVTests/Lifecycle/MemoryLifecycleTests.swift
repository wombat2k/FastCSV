@testable import FastCSV
import Foundation
import Testing

struct MemoryLifecycleTests {
    // MARK: - isSafe property

    @Test("Values from iterator are unsafe (ref)")
    func iteratorValuesAreUnsafe() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            for value in row.values {
                #expect(!value.isSafe, "Iterator values should be .ref (unsafe)")
            }
        }
    }

    @Test("Copied values are safe (own)")
    func copiedValuesAreSafe() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let copied = row.values[0].copy()
            #expect(copied.isSafe, "Copied value should be .own (safe)")
        }
    }

    @Test("Empty values are safe")
    func emptyValuesAreSafe() throws {
        let csv = "name,age\nAlice,\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let emptyValue = row.values[1]
            #expect(emptyValue.isEmpty)
            #expect(emptyValue.isSafe, "Empty values should be safe (.none)")
        }
    }

    // MARK: - copy() correctness

    @Test("copy() preserves string value")
    func copyPreservesStringValue() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let original = try row.values[0].string
            let copied = try row.values[0].copy().string
            #expect(original == copied)
            #expect(original == "Alice")
        }
    }

    @Test("copy() preserves numeric value")
    func copyPreservesNumericValue() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let original = try row.values[1].int
            let copied = try row.values[1].copy().int
            #expect(original == copied)
            #expect(original == 30)
        }
    }

    @Test("copy() on empty value stays empty")
    func copyEmptyStaysEmpty() throws {
        let csv = "name,age\nAlice,\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let copied = row.values[1].copy()
            #expect(copied.isEmpty)
            #expect(copied.isSafe)
        }
    }

    // MARK: - copyArray() / copyDictionary()

    @Test("copyArray() produces all-safe values")
    func copyArrayProducesSafeValues() throws {
        let csv = "name,age,city\nAlice,30,Boston\nBob,25,NYC\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyArray()
            for value in safeCopy {
                #expect(value.isSafe, "All values from copyArray() should be safe")
            }
        }
    }

    @Test("copyArray() preserves all values")
    func copyArrayPreservesValues() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeArrayRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyArray()
            #expect(try safeCopy[0].string == "Alice")
            #expect(try safeCopy[1].int == 30)
        }
    }

    @Test("copyDictionary() produces all-safe values")
    func copyDictionaryProducesSafeValues() throws {
        let csv = "name,age\nAlice,30\nBob,25\n"
        let rows = try FastCSV.makeDictionaryRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyDictionary()
            for (_, value) in safeCopy {
                #expect(value.isSafe, "All values from copyDictionary() should be safe")
            }
        }
    }

    @Test("copyDictionary() preserves all values")
    func copyDictionaryPreservesValues() throws {
        let csv = "name,age\nAlice,30\n"
        let rows = try FastCSV.makeDictionaryRows(fromString: csv)

        for row in rows {
            let safeCopy = row.copyDictionary()
            #expect(try safeCopy["name"]?.string == "Alice")
            #expect(try safeCopy["age"]?.int == 30)
        }
    }

    // MARK: - Survival across iterations

    @Test("Copied values survive across iterations")
    func copiedValuesSurviveAcrossIterations() throws {
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

    @Test("Copied array results survive across iterations")
    func copiedArrayResultsSurviveAcrossIterations() throws {
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

    @Test("Copied dictionary results survive across iterations")
    func copiedDictionaryResultsSurviveAcrossIterations() throws {
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

    @Test("Decodable values are owned strings, not buffer references")
    func decodableValuesAreOwned() throws {
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
