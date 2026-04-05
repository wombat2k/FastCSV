@testable import FastCSV
import Foundation
import Testing

@Suite("Custom Delimiter Tests")
struct CustomDelimiterTests {
    // MARK: - Tab-Separated Values

    @Test("TSV basic parsing")
    func testTSVBasic() throws {
        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fromString: "name\tage\tcity\nAlice\t30\tBoston\nBob\t25\tAustin\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 2)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["name"]?.stringIfPresent() == "Alice")
        #expect(try results[1].values["city"]?.stringIfPresent() == "Austin")
    }

    @Test("TSV with embedded commas (commas are literal, not delimiters)")
    func testTSVEmbeddedCommas() throws {
        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fromString: "name\taddress\nAlice\t\"123 Main St, Boston\"\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["address"]?.stringIfPresent() == "123 Main St, Boston")
    }

    @Test("TSV with empty fields")
    func testTSVEmptyFields() throws {
        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeArrayRows(fromString: "a\tb\tc\n\tmiddle\t\n", config: config)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].stringIfPresent() == nil)
        #expect(try results[0].values[1].stringIfPresent() == "middle")
        #expect(try results[0].values[2].stringIfPresent() == nil)
    }

    // MARK: - Semicolon-Separated Values

    @Test("Semicolon-separated basic parsing")
    func testSemicolonBasic() throws {
        let config = CSVParserConfig(delimiter: CSVFormat.semiColonSeparated.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fromString: "name;age;city\nAlice;30;Boston\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["name"]?.stringIfPresent() == "Alice")
        #expect(try results[0].values["age"]?.stringIfPresent() == "30")
    }

    @Test("Semicolon-separated with embedded commas and semicolons in quotes")
    func testSemicolonQuotedDelimiters() throws {
        let config = CSVParserConfig(delimiter: CSVFormat.semiColonSeparated.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fromString: "name;note\nAlice;\"has; semicolons, and commas\"\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["note"]?.stringIfPresent() == "has; semicolons, and commas")
    }

    // MARK: - Pipe-Separated (Custom)

    @Test("Pipe-separated basic parsing")
    func testPipeSeparated() throws {
        let config = CSVParserConfig(delimiter: Delimiter(field: UInt8(ascii: "|")))
        let rows = try FastCSV.makeDictionaryRows(fromString: "name|age|city\nAlice|30|Boston\nBob|25|Austin\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 2)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["name"]?.stringIfPresent() == "Alice")
        #expect(try results[1].values["city"]?.stringIfPresent() == "Austin")
    }

    @Test("Pipe-separated with commas and tabs in data (literal, not delimiters)")
    func testPipeLiteralCommasAndTabs() throws {
        let config = CSVParserConfig(delimiter: Delimiter(field: UInt8(ascii: "|")))
        let rows = try FastCSV.makeArrayRows(fromString: "col1|col2\nhello, world|tab\there\n", config: config)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))
        #expect(try results[0].values[0].stringIfPresent() == "hello, world")
        #expect(try results[0].values[1].stringIfPresent() == "tab\there")
    }

    // MARK: - Custom Quote Character

    @Test("Single-quote as quote delimiter")
    func testSingleQuoteDelimiter() throws {
        let config = CSVParserConfig(delimiter: Delimiter(quote: UInt8(ascii: "'")))
        let rows = try FastCSV.makeDictionaryRows(fromString: "name,note\nAlice,'has, commas'\n", config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))
        #expect(try results[0].values["note"]?.stringIfPresent(quoteChar: config.delimiter.quoteByte) == "has, commas")
    }

    // MARK: - File I/O Helper

    @Test("createTemporaryCSVFile respects custom delimiters")
    func testHelperWithCustomDelimiters() async throws {
        let delimiter = Delimiter(field: UInt8(ascii: "|"))
        let config = CSVParserConfig(delimiter: delimiter)

        try await TestUtils.runTest(
            testName: "Pipe via helper",
            contentHeaders: ["name", "age"],
            contentRows: [["Alice", "30"], ["Bob", "25"]],
            config: config,
            outputFormat: .array,
            validate: { (results: [CSVArrayResult]) in
                #expect(results.count == 2)
                #expect(TestUtils.isErrorFree(arrayResult: results))
                let name = try results[0].values[0].stringIfPresent()
                #expect(name == "Alice")
            }
        )
    }

    // MARK: - String and Character Initializers

    @Test("String initializer with valid single-character delimiters")
    func testStringInitializerValid() throws {
        let delimiter = try Delimiter(row: "\n", field: ",", quote: "\"")

        #expect(delimiter.rowByte == UInt8(ascii: "\n"))
        #expect(delimiter.fieldByte == UInt8(ascii: ","))
        #expect(delimiter.quoteByte == UInt8(ascii: "\""))
    }

    @Test("Character initializer with valid single-character delimiters")
    func testCharacterInitializerValid() throws {
        let delimiter = try Delimiter(row: Character("\n"), field: Character(","), quote: Character("\""))

        #expect(delimiter.rowByte == UInt8(ascii: "\n"))
        #expect(delimiter.fieldByte == UInt8(ascii: ","))
        #expect(delimiter.quoteByte == UInt8(ascii: "\""))
    }

    // MARK: - Invalid Delimiter Tests

    @Test("String initializer with invalid multi-character delimiters")
    func testStringInitializerInvalidMultiCharacter() throws {
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n\n", field: ",", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: ",,", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: ",", quote: "\"\"")
        }
    }

    @Test("String initializer with invalid non-ASCII delimiters")
    func testStringInitializerInvalidNonASCII() throws {
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "😀", field: ",", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: "😀", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: ",", quote: "😀")
        }
    }

    @Test("Character initializer with invalid non-ASCII delimiters")
    func testCharacterInitializerInvalidNonASCII() throws {
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: Character("😀"), field: Character(","), quote: Character("\""))
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: Character("\n"), field: Character("😀"), quote: Character("\""))
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: Character("\n"), field: Character(","), quote: Character("😀"))
        }
    }

    @Test("String initializer with empty string delimiters")
    func testStringInitializerEmpty() throws {
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "", field: ",", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: "", quote: "\"")
        }
        #expect(throws: CSVError.self) {
            _ = try Delimiter(row: "\n", field: ",", quote: "")
        }
    }

    @Test("Default string initializer produces expected delimiters")
    func testDefaultInitializer() throws {
        let rowProvided = try Delimiter(row: "\t")
        #expect(rowProvided.fieldByte == UInt8(ascii: ","))
        #expect(rowProvided.quoteByte == UInt8(ascii: "\""))

        let fieldProvided = try Delimiter(field: "\t")
        #expect(fieldProvided.rowByte == UInt8(ascii: "\n"))
        #expect(fieldProvided.quoteByte == UInt8(ascii: "\""))

        let quoteProvided = try Delimiter(quote: "\t")
        #expect(quoteProvided.rowByte == UInt8(ascii: "\n"))
        #expect(quoteProvided.fieldByte == UInt8(ascii: ","))
    }

    @Test("Default character initializer produces expected delimiters")
    func testDefaultCharacterInitializer() throws {
        let rowProvided = try Delimiter(row: Character("\t"))
        #expect(rowProvided.fieldByte == UInt8(ascii: ","))
        #expect(rowProvided.quoteByte == UInt8(ascii: "\""))

        let fieldProvided = try Delimiter(field: Character("\t"))
        #expect(fieldProvided.rowByte == UInt8(ascii: "\n"))
        #expect(fieldProvided.quoteByte == UInt8(ascii: "\""))

        let quoteProvided = try Delimiter(quote: Character("\t"))
        #expect(quoteProvided.rowByte == UInt8(ascii: "\n"))
        #expect(quoteProvided.fieldByte == UInt8(ascii: ","))
    }
}
