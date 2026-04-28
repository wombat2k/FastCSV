@testable import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif
import Testing

struct CSVValueTests {
    // MARK: - Owned CSVValue

    /// These tests check the behavior of CSVValue when it owns its buffer.
    @Test
    func `CSVValue as owned String`() throws {
        let inputValue = "Original"
        var bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.stringIfPresent() ?? ""

        #expect(csvValue.isSafe, "CSVValue should be safe")
        #expect(collectedValue == inputValue)

        bytes = "Mutated!".utf8.map(\.self)
        let newCSVValue = try csvValue.stringIfPresent() ?? ""

        #expect(collectedValue == newCSVValue, "new CSVValue should not be different from the original CSVValue")
    }

    @Test
    func `CSVValue as owned Integer`() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.intIfPresent ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test
    func `CSVValue as owned Double`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.doubleIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test
    func `CSVValue as owned Float`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.floatIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test
    func `CSVValue as owned Decimal`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.decimalIfPresent ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test(arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func `CSVValue as owned Bool`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test(arguments: ["invalid", "123abc", "yesno"])
    func `CSVValue as owned Bool with invalid values`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(throws: CSVError.self) {
            _ = try csvValue.boolIfPresent
        }
    }

    @Test(arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func `CSVValue as owned Bool with false values`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == false, "Collected value should be false")
    }

    @Test
    func `CSVValue as owned String with empty buffer`() throws {
        // Create an empty buffer
        let bytes = [UInt8]()

        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(csvValue.isSafe, "CSVValue should be safe even with empty buffer")

        // Attempt to get a string from the empty buffer
        let result = try csvValue.stringIfPresent()

        #expect(result == nil, "Result should be nil when buffer is empty")
    }

    @Test
    func `CSVValue as owned String with empty String`() throws {
        // Create an empty string
        let inputValue = "\"\""
        let bytes = [UInt8](inputValue.utf8)

        // Create a CSVValue from the empty string
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(csvValue.isSafe, "CSVValue should be safe even with empty string")

        // Attempt to get a string from the empty CSVValue
        let result = try csvValue.stringIfPresent()

        #expect(result == "", "Result should be empty string when CSVValue contains quoted empty string")
    }

    // MARK: - Reference CSVValue

    /// These tests check the behavior of CSVValue when it references a buffer.
    @Test
    func `CSVValue as borrowed String`() throws {
        // Create a mutable buffer
        var buffer = [UInt8]("Original".utf8)

        // Create a CSVValue that references this buffer
        let csvValue: CSVValue

        // We need to use withUnsafeBufferPointer to get a reference to our mutable buffer
        csvValue = buffer.withUnsafeBufferPointer { bufferPointer in
            CSVValue(buffer: bufferPointer)
        }

        #expect(!csvValue.isSafe, "CSVValue should not be safe")

        // Get initial value
        let initialValue = try csvValue.stringIfPresent() ?? ""
        #expect(initialValue == "Original", "Initial value should match buffer contents")

        let mutatedBytes = [UInt8]("Mutated!".utf8)
        for (i, byte) in mutatedBytes.prefix(buffer.count).enumerated() {
            buffer[i] = byte
        }

        // Now the referenced value should reflect the change
        let modifiedValue = try csvValue.stringIfPresent() ?? ""
        #expect(modifiedValue != initialValue, "After buffer modification, CSVValue should reflect changes")
        #expect(modifiedValue.hasPrefix("Mutated"), "Modified value should contain the mutated bytes")
    }

    @Test
    func `CSVValue as borrowed String with nil`() throws {
        // Create a CSVValue with a nil buffer
        let csvValue = CSVValue(buffer: nil)

        #expect(csvValue.isSafe, "CSVValue should be safe even with nil buffer")

        // Attempt to get a string from the nil buffer
        let result = try csvValue.stringIfPresent()

        #expect(result == nil, "Result should be nil when buffer is nil")
    }

    @Test
    func `CSVValue as borrowed Int`() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.intIfPresent ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test
    func `CSVValue as borrowed Double`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.doubleIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test
    func `CSVValue as borrowed Float`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.floatIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test
    func `CSVValue as borrowed Decimal`() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.decimalIfPresent ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test(arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func `CSVValue as borrowed Bool`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test(arguments: ["invalid", "123abc", "yesno"])
    func `CSVValue as borrowed Bool with invalid values`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)

        #expect(throws: CSVError.self) {
            _ = try csvValue.boolIfPresent
        }
    }

    @Test(arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func `CSVValue as borrowed Bool with false values`(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == false, "Collected value should be false")
    }

    @Test
    func `Copy of CSVValue is safe`() throws {
        let inputValue = "Original"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        #expect(!csvValue.isSafe, "CSVValue should not be safe")

        let safeCopy = csvValue.copy()

        #expect(safeCopy.isSafe, "Safe copy should be safe")

        let safeValue = try safeCopy.stringIfPresent() ?? ""
        #expect(safeValue == inputValue, "Safe copy should have the same value as the original CSVValue")
    }

    // MARK: - Non-Optional Accessors

    @Test
    func `Non-optional string returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("hello".utf8), source: .own)
        #expect(try csvValue.string == "hello")
    }

    @Test
    func `Non-optional string throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.string
        }
    }

    @Test
    func `Non-optional string computed property matches method`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("test".utf8), source: .own)
        #expect(try csvValue.string == csvValue.string())
    }

    @Test
    func `Non-optional int returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("42".utf8), source: .own)
        #expect(try csvValue.int == 42)
    }

    @Test
    func `Non-optional int throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.int
        }
    }

    @Test
    func `Non-optional double returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("3.14".utf8), source: .own)
        #expect(try csvValue.double == 3.14)
    }

    @Test
    func `Non-optional double throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.double
        }
    }

    @Test
    func `Non-optional float returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2.5".utf8), source: .own)
        #expect(try csvValue.float == 2.5)
    }

    @Test
    func `Non-optional float throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.float
        }
    }

    @Test
    func `Non-optional decimal returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("19.99".utf8), source: .own)
        #expect(try csvValue.decimal == Decimal(string: "19.99"))
    }

    @Test
    func `Non-optional decimal throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.decimal
        }
    }

    @Test
    func `Non-optional bool returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("true".utf8), source: .own)
        #expect(try csvValue.bool == true)
    }

    @Test
    func `Non-optional bool throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.bool
        }
    }

    // MARK: - Optional Computed Properties (stringIfPresent as property)

    @Test
    func `stringIfPresent computed property returns value`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("hello".utf8), source: .own)
        #expect(try csvValue.stringIfPresent == "hello")
    }

    @Test
    func `stringIfPresent computed property returns nil on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(try csvValue.stringIfPresent == nil)
    }

    // MARK: - Date Accessors

    @Test
    func `Date with default strategy (ISO 8601 yyyy-MM-dd)`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2026-03-29".utf8), source: .own)
        let result = try csvValue.date()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 29)
    }

    @Test
    func `Date with custom strategy`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("03/29/2026".utf8), source: .own)
        let style = Date.VerbatimFormatStyle(
            format: "\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)",
            locale: .init(identifier: "en_US_POSIX"),
            timeZone: .gmt,
            calendar: .init(identifier: .gregorian),
        )

        let result = try csvValue.date(strategy: .formatStyle(style))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 29)
    }

    @Test
    func `Date throws on invalid string`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("not-a-date".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.date()
        }
    }

    @Test
    func `Date throws on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.date()
        }
    }

    @Test
    func `dateIfPresent returns nil on empty`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(try csvValue.dateIfPresent() == nil)
    }

    @Test
    func `dateIfPresent returns value on valid date`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2026-03-29".utf8), source: .own)
        let result = try csvValue.dateIfPresent()
        #expect(result != nil)
    }

    @Test
    func `dateIfPresent throws on invalid string`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("garbage".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.dateIfPresent()
        }
    }

    // MARK: - Quoted Values Are Strings

    @Test
    func `Quoted integer is treated as string, not number`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("\"42\"".utf8), source: .own)
        // Quoted field is a string — intIfPresent should fail because the raw bytes include quotes
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
        // But stringIfPresent strips quotes and returns the string content
        #expect(try csvValue.stringIfPresent() == "42")
    }

    // MARK: - Direct Byte Parsing Edge Cases

    @Test
    func `Integer parsing: negative values`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-42".utf8), source: .own)
        #expect(try csvValue.intIfPresent == -42)
    }

    @Test
    func `Integer parsing: positive sign`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("+42".utf8), source: .own)
        #expect(try csvValue.intIfPresent == 42)
    }

    @Test
    func `Integer parsing: leading zeros`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("007".utf8), source: .own)
        #expect(try csvValue.intIfPresent == 7)
    }

    @Test
    func `Integer parsing: overflow throws`() throws {
        // Int8 max is 127
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("128".utf8), source: .own)
        #expect(throws: CSVError.self) {
            let _: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        }
    }

    @Test
    func `Integer parsing: Int8.min parses correctly`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-128".utf8), source: .own)
        let result: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        #expect(result == Int8.min)
    }

    @Test
    func `Integer parsing: negative unsigned throws`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-1".utf8), source: .own)
        #expect(throws: CSVError.self) {
            let _: UInt? = try csvValue.fixedWidthIntegerIfPresent()
        }
    }

    @Test
    func `Integer parsing: bare sign throws`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
    }

    @Test
    func `Integer parsing: non-digit throws`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("12a3".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
    }

    @Test
    func `Double parsing: scientific notation`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("1.5e2".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == 150.0)
    }

    @Test
    func `Double parsing: negative`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-3.14".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == -3.14)
    }

    @Test
    func `Double parsing: infinity`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("inf".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == Double.infinity)
    }

    @Test
    func `Double parsing: leading whitespace rejects`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](" 3.14".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.doubleIfPresent
        }
    }

    @Test
    func `fixedWidthIntegerIfPresent generic works for multiple types`() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("42".utf8), source: .own)
        let i8: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        let u16: UInt16? = try csvValue.fixedWidthIntegerIfPresent()
        let i64: Int64? = try csvValue.fixedWidthIntegerIfPresent()
        #expect(i8 == 42)
        #expect(u16 == 42)
        #expect(i64 == 42)
    }
}
