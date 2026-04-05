@testable import FastCSV
import Foundation
import Testing

struct CSVValueTests {
    // MARK: - Owned CSVValue

    /// These tests check the behavior of CSVValue when it owns its buffer.
    @Test("CSVValue as owned String")
    func cSVValueAsString() throws {
        let inputValue = "Original"
        var bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.stringIfPresent() ?? ""

        #expect(csvValue.isSafe, "CSVValue should be safe")
        #expect(collectedValue == inputValue)

        bytes = "Mutated!".utf8.map { $0 }
        let newCSVValue = try csvValue.stringIfPresent() ?? ""

        #expect(collectedValue == newCSVValue, "new CSVValue should not be different from the original CSVValue")
    }

    @Test("CSVValue as owned Integer")
    func cSVValueAsInteger() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.intIfPresent ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test("CSVValue as owned Double")
    func cSVValueAsDouble() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.doubleIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Float")
    func cSVValueAsFloat() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.floatIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Decimal")
    func cSVValueAsDecimal() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.decimalIfPresent ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Bool", arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func cSVValueAsBool(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test("CSVValue as owned Bool with invalid values", arguments: ["invalid", "123abc", "yesno"])
    func cSVValueAsBoolTrueWithInvalidValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(throws: CSVError.self) {
            _ = try csvValue.boolIfPresent
        }
    }

    @Test("CSVValue as owned Bool with false values", arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func cSVValueAsBoolWithFalseValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == false, "Collected value should be false")
    }

    @Test("CSVValue as owned String with empty buffer")
    func cSVValueWithEmptyBuffer() throws {
        // Create an empty buffer
        let bytes = [UInt8]()

        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(csvValue.isSafe, "CSVValue should be safe even with empty buffer")

        // Attempt to get a string from the empty buffer
        let result = try csvValue.stringIfPresent()

        #expect(result == nil, "Result should be nil when buffer is empty")
    }

    @Test("CSVValue as owned String with empty String")
    func cSVValueWithEmptyString() throws {
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
    @Test("CSVValue as borrowed String")
    func cSVValueWithMutableBuffer() throws {
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

    @Test("CSVValue as borrowed String with nil")
    func cSVValueWithNilBuffer() throws {
        // Create a CSVValue with a nil buffer
        let csvValue = CSVValue(buffer: nil)

        #expect(csvValue.isSafe, "CSVValue should be safe even with nil buffer")

        // Attempt to get a string from the nil buffer
        let result = try csvValue.stringIfPresent()

        #expect(result == nil, "Result should be nil when buffer is nil")
    }

    @Test("CSVValue as borrowed Int")
    func cSVValueWithBorrowedInt() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.intIfPresent ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test("CSVValue as borrowed Double")
    func cSVValueWithBorrowedDouble() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.doubleIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Float")
    func cSVValueWithBorrowedFloat() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.floatIfPresent ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Decimal")
    func cSVValueWithBorrowedDecimal() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.decimalIfPresent ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Bool", arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func cSVValueWithBorrowedBool(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test("CSVValue as borrowed Bool with invalid values", arguments: ["invalid", "123abc", "yesno"])
    func cSVValueWithBorrowedBoolTrueWithInvalidValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)

        #expect(throws: CSVError.self) {
            _ = try csvValue.boolIfPresent
        }
    }

    @Test("CSVValue as borrowed Bool with false values", arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func cSVValueWithBorrowedBoolWithFalseValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.boolIfPresent ?? false

        #expect(collectedValue == false, "Collected value should be false")
    }

    @Test("Copy of CSVValue is safe")
    func testSafeCopy() throws {
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

    @Test("Non-optional string returns value")
    func nonOptionalString() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("hello".utf8), source: .own)
        #expect(try csvValue.string == "hello")
    }

    @Test("Non-optional string throws on empty")
    func nonOptionalStringThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.string
        }
    }

    @Test("Non-optional string computed property matches method")
    func nonOptionalStringPropertyMatchesMethod() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("test".utf8), source: .own)
        #expect(try csvValue.string == csvValue.string())
    }

    @Test("Non-optional int returns value")
    func nonOptionalInt() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("42".utf8), source: .own)
        #expect(try csvValue.int == 42)
    }

    @Test("Non-optional int throws on empty")
    func nonOptionalIntThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.int
        }
    }

    @Test("Non-optional double returns value")
    func nonOptionalDouble() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("3.14".utf8), source: .own)
        #expect(try csvValue.double == 3.14)
    }

    @Test("Non-optional double throws on empty")
    func nonOptionalDoubleThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.double
        }
    }

    @Test("Non-optional float returns value")
    func nonOptionalFloat() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2.5".utf8), source: .own)
        #expect(try csvValue.float == 2.5)
    }

    @Test("Non-optional float throws on empty")
    func nonOptionalFloatThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.float
        }
    }

    @Test("Non-optional decimal returns value")
    func nonOptionalDecimal() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("19.99".utf8), source: .own)
        #expect(try csvValue.decimal == Decimal(string: "19.99"))
    }

    @Test("Non-optional decimal throws on empty")
    func nonOptionalDecimalThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.decimal
        }
    }

    @Test("Non-optional bool returns value")
    func nonOptionalBool() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("true".utf8), source: .own)
        #expect(try csvValue.bool == true)
    }

    @Test("Non-optional bool throws on empty")
    func nonOptionalBoolThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.bool
        }
    }

    // MARK: - Optional Computed Properties (stringIfPresent as property)

    @Test("stringIfPresent computed property returns value")
    func stringIfPresentProperty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("hello".utf8), source: .own)
        #expect(try csvValue.stringIfPresent == "hello")
    }

    @Test("stringIfPresent computed property returns nil on empty")
    func stringIfPresentPropertyNilOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(try csvValue.stringIfPresent == nil)
    }

    // MARK: - Date Accessors

    @Test("Date with default formatter (yyyy-MM-dd)")
    func dateDefaultFormatter() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2026-03-29".utf8), source: .own)
        let result = try csvValue.date()

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 29)
    }

    @Test("Date with custom formatter")
    func dateCustomFormatter() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("03/29/2026".utf8), source: .own)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"

        let result = try csvValue.date(formatter: formatter)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 29)
    }

    @Test("Date throws on invalid string")
    func dateThrowsOnInvalid() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("not-a-date".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.date()
        }
    }

    @Test("Date throws on empty")
    func dateThrowsOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.date()
        }
    }

    @Test("dateIfPresent returns nil on empty")
    func dateIfPresentNilOnEmpty() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](), source: .own)
        #expect(try csvValue.dateIfPresent() == nil)
    }

    @Test("dateIfPresent returns value on valid date")
    func dateIfPresentReturnsValue() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("2026-03-29".utf8), source: .own)
        let result = try csvValue.dateIfPresent()
        #expect(result != nil)
    }

    @Test("dateIfPresent throws on invalid string")
    func dateIfPresentThrowsOnInvalid() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("garbage".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.dateIfPresent()
        }
    }

    // MARK: - Quoted Values Are Strings

    @Test("Quoted integer is treated as string, not number")
    func quotedIntIsString() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("\"42\"".utf8), source: .own)
        // Quoted field is a string — intIfPresent should fail because the raw bytes include quotes
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
        // But stringIfPresent strips quotes and returns the string content
        #expect(try csvValue.stringIfPresent() == "42")
    }

    // MARK: - Direct Byte Parsing Edge Cases

    @Test("Integer parsing: negative values")
    func negativeInt() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-42".utf8), source: .own)
        #expect(try csvValue.intIfPresent == -42)
    }

    @Test("Integer parsing: positive sign")
    func positiveSignInt() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("+42".utf8), source: .own)
        #expect(try csvValue.intIfPresent == 42)
    }

    @Test("Integer parsing: leading zeros")
    func leadingZerosInt() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("007".utf8), source: .own)
        #expect(try csvValue.intIfPresent == 7)
    }

    @Test("Integer parsing: overflow throws")
    func intOverflow() throws {
        // Int8 max is 127
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("128".utf8), source: .own)
        #expect(throws: CSVError.self) {
            let _: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        }
    }

    @Test("Integer parsing: Int8.min parses correctly")
    func int8Min() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-128".utf8), source: .own)
        let result: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        #expect(result == Int8.min)
    }

    @Test("Integer parsing: negative unsigned throws")
    func negativeUnsigned() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-1".utf8), source: .own)
        #expect(throws: CSVError.self) {
            let _: UInt? = try csvValue.fixedWidthIntegerIfPresent()
        }
    }

    @Test("Integer parsing: bare sign throws")
    func bareSign() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
    }

    @Test("Integer parsing: non-digit throws")
    func nonDigit() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("12a3".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.intIfPresent
        }
    }

    @Test("Double parsing: scientific notation")
    func doubleScientific() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("1.5e2".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == 150.0)
    }

    @Test("Double parsing: negative")
    func negativeDouble() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("-3.14".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == -3.14)
    }

    @Test("Double parsing: infinity")
    func doubleInfinity() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("inf".utf8), source: .own)
        #expect(try csvValue.doubleIfPresent == Double.infinity)
    }

    @Test("Double parsing: leading whitespace rejects")
    func doubleLeadingWhitespace() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8](" 3.14".utf8), source: .own)
        #expect(throws: CSVError.self) {
            _ = try csvValue.doubleIfPresent
        }
    }

    @Test("fixedWidthIntegerIfPresent generic works for multiple types")
    func genericFixedWidthInteger() throws {
        let csvValue = TestUtils.createCSVValue(from: [UInt8]("42".utf8), source: .own)
        let i8: Int8? = try csvValue.fixedWidthIntegerIfPresent()
        let u16: UInt16? = try csvValue.fixedWidthIntegerIfPresent()
        let i64: Int64? = try csvValue.fixedWidthIntegerIfPresent()
        #expect(i8 == 42)
        #expect(u16 == 42)
        #expect(i64 == 42)
    }
}
