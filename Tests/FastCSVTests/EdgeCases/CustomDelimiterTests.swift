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

        let name0 = try results[0].values["name"]?.getString()
        let city1 = try results[1].values["city"]?.getString()
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

        let address = try results[0].values["address"]?.getString()
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

        let first = try results[0].values[0].getString()
        let middle = try results[0].values[1].getString()
        let last = try results[0].values[2].getString()
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

        let name = try results[0].values["name"]?.getString()
        let age = try results[0].values["age"]?.getString()
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

        let note = try results[0].values["note"]?.getString()
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

        let name0 = try results[0].values["name"]?.getString()
        let city1 = try results[1].values["city"]?.getString()
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

        let col1 = try results[0].values[0].getString()
        let col2 = try results[0].values[1].getString()
        #expect(col1 == "hello, world")
        #expect(col2 == "tab\there")
    }

    // MARK: - Custom Quote Character

    @Test("Single-quote as value delimiter")
    func testSingleQuoteDelimiter() async throws {
        let content = "name,note\nAlice,'has, commas'\n"
        let url = try TestUtils.createRawCSVFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let delimiter = Delimiter(value: UInt8(ascii: "'"))
        let config = CSVParserConfig(delimiter: delimiter)
        let rows = try FastCSV.makeDictionaryRows(fileURL: url, hasHeaders: true, config: config)
        var results: [CSVDictionaryResult] = []
        for result in rows {
            results.append(CSVDictionaryResult(values: result.copyDictionary(), error: result.error))
        }

        #expect(results.count == 1)
        #expect(TestUtils.isErrorFree(dictionaryResult: results))

        let note = try results[0].values["note"]?.getString(quoteChar: config.delimiter.value)
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

                let name = try results[0].values[0].getString()
                #expect(name == "Alice")
            }
        )
    }
}
