@testable import FastCSV
import Foundation
import Testing

@Suite("Custom Delimiter Tests")
struct CustomDelimiterTests {
    // MARK: - Tab-Separated Values

    @Test("TSV basic parsing")
    func testTSVBasic() async throws {
        let content = "name\tage\tcity\nAlice\t30\tBoston\nBob\t25\tAustin\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 2)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let name0 = try results[0].values["name"]?.stringIfPresent()
        let city1 = try results[1].values["city"]?.stringIfPresent()
        #expect(name0 == "Alice")
        #expect(city1 == "Austin")
    }

    @Test("TSV with embedded commas (commas are literal, not delimiters)")
    func testTSVEmbeddedCommas() async throws {
        let content = "name\taddress\nAlice\t\"123 Main St, Boston\"\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let address = try results[0].values["address"]?.stringIfPresent()
        #expect(address == "123 Main St, Boston")
    }

    @Test("TSV with empty fields")
    func testTSVEmptyFields() async throws {
        let content = "a\tb\tc\n\tmiddle\t\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = CSVParserConfig(delimiter: CSVFormat.tsv.delimiter)
        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let first = try results[0].values[0].stringIfPresent()
        let middle = try results[0].values[1].stringIfPresent()
        let last = try results[0].values[2].stringIfPresent()
        #expect(first == nil, "Empty field should be nil")
        #expect(middle == "middle")
        #expect(last == nil, "Empty field should be nil")
    }

    // MARK: - Semicolon-Separated Values

    @Test("Semicolon-separated basic parsing")
    func testSemicolonBasic() async throws {
        let content = "name;age;city\nAlice;30;Boston\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = CSVParserConfig(delimiter: CSVFormat.semiColonSeparated.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let name = try results[0].values["name"]?.stringIfPresent()
        let age = try results[0].values["age"]?.stringIfPresent()
        #expect(name == "Alice")
        #expect(age == "30")
    }

    @Test("Semicolon-separated with embedded commas and semicolons in quotes")
    func testSemicolonQuotedDelimiters() async throws {
        // Semicolons inside quotes should be literal, commas are always literal
        let content = "name;note\nAlice;\"has; semicolons, and commas\"\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let config = CSVParserConfig(delimiter: CSVFormat.semiColonSeparated.delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let note = try results[0].values["note"]?.stringIfPresent()
        #expect(note == "has; semicolons, and commas")
    }

    // MARK: - Pipe-Separated (Custom)

    @Test("Pipe-separated basic parsing")
    func testPipeSeparated() async throws {
        let content = "name|age|city\nAlice|30|Boston\nBob|25|Austin\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let delimiter = Delimiter(field: UInt8(ascii: "|"))
        let config = CSVParserConfig(delimiter: delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 2)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let name0 = try results[0].values["name"]?.stringIfPresent()
        let city1 = try results[1].values["city"]?.stringIfPresent()
        #expect(name0 == "Alice")
        #expect(city1 == "Austin")
    }

    @Test("Pipe-separated with commas and tabs in data (literal, not delimiters)")
    func testPipeLiteralCommasAndTabs() async throws {
        let content = "col1|col2\nhello, world|tab\there\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let delimiter = Delimiter(field: UInt8(ascii: "|"))
        let config = CSVParserConfig(delimiter: delimiter)
        let rows = try FastCSV.makeArrayRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVArrayResult] = []
        for result in rows {
            results.append(CSVArrayResult(values: result.copyArray(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(arrayResult: results))

        let col1 = try results[0].values[0].stringIfPresent()
        let col2 = try results[0].values[1].stringIfPresent()
        #expect(col1 == "hello, world")
        #expect(col2 == "tab\there")
    }

    // MARK: - Custom Quote Character

    @Test("Single-quote as quote delimiter")
    func testSingleQuoteDelimiter() async throws {
        let content = "name,note\nAlice,'has, commas'\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let delimiter = Delimiter(quote: UInt8(ascii: "'"))
        let config = CSVParserConfig(delimiter: delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let note = try results[0].values["note"]?.stringIfPresent(quoteChar: config.delimiter.quote)
        #expect(note == "has, commas")
    }

    // MARK: - Delimiter Interactions via createTemporaryCSVFile

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
    func testStringInitializerValid() async throws {
        let delimiter = try Delimiter(row: "\n", field: ",", quote: "\"")
        
        #expect(delimiter.row == UInt8(ascii: "\n"))
        #expect(delimiter.field == UInt8(ascii: ","))
        #expect(delimiter.quote == UInt8(ascii: "\""))
    }

    @Test("Character initializer with valid single-character delimiters")
    func testCharacterInitializerValid() async throws {
        let delimiter = try Delimiter(row: Character("\n"), field: Character(","), quote: Character("\""))
        
        #expect(delimiter.row == UInt8(ascii: "\n"))
        #expect(delimiter.field == UInt8(ascii: ","))
        #expect(delimiter.quote == UInt8(ascii: "\""))
    }

    // MARK: - Invalid Delimiter Tests
    @Test("String initializer with invalid multi-character delimiters")
    func testStringInitializerInvalidMultiCharacter() async throws {
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
    func testStringInitializerInvalidNonASCII() async throws {
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
    func testCharacterInitializerInvalidNonASCII() async throws {
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
    func testStringInitializerEmpty() async throws {
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
    func testDefaultInitializer() async throws {
        let rowProvided = try Delimiter(row: "\t")
        
        #expect(rowProvided.field == UInt8(ascii: ","))
        #expect(rowProvided.quote == UInt8(ascii: "\""))

        let fieldProvided = try Delimiter(field: "\t")
        #expect(fieldProvided.row == UInt8(ascii: "\n"))
        #expect(fieldProvided.quote == UInt8(ascii: "\""))

        let quoteProvided = try Delimiter(quote: "\t")
        #expect(quoteProvided.row == UInt8(ascii: "\n"))
        #expect(quoteProvided.field == UInt8(ascii: ","))
    }  

    @Test("Default character initializer produces expected delimiters")
    func testDefaultCharacterInitializer() async throws {
        let rowProvided = try Delimiter(row: Character("\t"))
        #expect(rowProvided.field == UInt8(ascii: ","))
        #expect(rowProvided.quote == UInt8(ascii: "\""))
 
        let fieldProvided = try Delimiter(field: Character("\t"))
        #expect(fieldProvided.row == UInt8(ascii: "\n"))
        #expect(fieldProvided.quote == UInt8(ascii: "\""))
 
        let quoteProvided = try Delimiter(quote: Character("\t"))
        #expect(quoteProvided.row == UInt8(ascii: "\n"))
        #expect(quoteProvided.field == UInt8(ascii: ","))
    }
}