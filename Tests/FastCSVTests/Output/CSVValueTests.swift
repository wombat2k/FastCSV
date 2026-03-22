@testable import FastCSV
import Foundation
import Testing

@Suite("CSV Value Tests")
struct CSVValueTests {
    // MARK: - Owned CSVValue

    // These tests check the behavior of CSVValue when it owns its buffer.
    @Test("CSVValue as owned String")
    func testCSVValueAsString() throws {
        let inputValue = "Original"
        var bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getString() ?? ""

        #expect(csvValue.isSafe, "CSVValue should be safe")
        #expect(collectedValue == inputValue)

        bytes = "Mutated!".utf8.map { $0 }
        let newCSVValue = try csvValue.getString() ?? ""

        #expect(collectedValue == newCSVValue, "new CSVValue should not be different from the original CSVValue")
    }

    @Test("CSVValue as owned Integer")
    func testCSVValueAsInteger() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getInt() ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test("CSVValue as owned Double")
    func testCSVValueAsDouble() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getDouble() ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Float")
    func testCSVValueAsFloat() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getFloat() ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Decimal")
    func testCSVValueAsDecimal() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getDecimal() ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test("CSVValue as owned Bool", arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func testCSVValueAsBool(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getBool() ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test("CSVValue as owned Bool with invalid values", arguments: ["invalid", "123abc", "yesno"])
    func testCSVValueAsBoolTrueWithInvalidValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(throws: CSVError.self) {
            _ = try csvValue.getBool()
        }
    }

    @Test("CSVValue as owned Bool with false values", arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func testCSVValueAsBoolWithFalseValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)
        let collectedValue = try csvValue.getBool() ?? false

        #expect(collectedValue == false, "Collected value should be false")
    }

    @Test("CSVValue as owned String with empty buffer")
    func testCSVValueWithEmptyBuffer() throws {
        // Create an empty buffer
        let bytes = [UInt8]()

        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(csvValue.isSafe, "CSVValue should be safe even with empty buffer")

        // Attempt to get a string from the empty buffer
        let result = try csvValue.getString()

        #expect(result == nil, "Result should be nil when buffer is empty")
    }

    @Test("CSVValue as owned String with empty String")
    func testCSVValueWithEmptyString() throws {
        // Create an empty string
        let inputValue = "\"\""
        let bytes = [UInt8](inputValue.utf8)

        // Create a CSVValue from the empty string
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .own)

        #expect(csvValue.isSafe, "CSVValue should be safe even with empty string")

        // Attempt to get a string from the empty CSVValue
        let result = try csvValue.getString()

        #expect(result == "", "Result should be empty string when CSVValue contains quoted empty string")
    }

    // MARK: - Reference CSVValue

    // These tests check the behavior of CSVValue when it references a buffer.
    @Test("CSVValue as borrowed String")
    func testCSVValueWithMutableBuffer() throws {
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
        let initialValue = try csvValue.getString() ?? ""
        #expect(initialValue == "Original", "Initial value should match buffer contents")

        let mutatedBytes = [UInt8]("Mutated!".utf8)
        for (i, byte) in mutatedBytes.prefix(buffer.count).enumerated() {
            buffer[i] = byte
        }

        // Now the referenced value should reflect the change
        let modifiedValue = try csvValue.getString() ?? ""
        #expect(modifiedValue != initialValue, "After buffer modification, CSVValue should reflect changes")
        #expect(modifiedValue.hasPrefix("Mutated"), "Modified value should contain the mutated bytes")
    }

    @Test("CSVValue as borrowed String with nil")
    func testCSVValueWithNilBuffer() throws {
        // Create a CSVValue with a nil buffer
        let csvValue = CSVValue(buffer: nil)

        #expect(csvValue.isSafe, "CSVValue should be safe even with nil buffer")

        // Attempt to get a string from the nil buffer
        let result = try csvValue.getString()

        #expect(result == nil, "Result should be nil when buffer is nil")
    }

    @Test("CSVValue as borrowed Int")
    func testCSVValueWithBorrowedInt() throws {
        let inputValue = "123"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getInt() ?? 0

        #expect(collectedValue == 123, "Collected value should be 123")
    }

    @Test("CSVValue as borrowed Double")
    func testCSVValueWithBorrowedDouble() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getDouble() ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Float")
    func testCSVValueWithBorrowedFloat() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getFloat() ?? 0.0

        #expect(collectedValue == 123.456, "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Decimal")
    func testCSVValueWithBorrowedDecimal() throws {
        let inputValue = "123.456"
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getDecimal() ?? 0.0

        #expect(collectedValue == Decimal(string: inputValue), "Collected value should be 123.456")
    }

    @Test("CSVValue as borrowed Bool", arguments: ["true", "TRUE", "yes", "yEs", "1", "y", "Y"])
    func testCSVValueWithBorrowedBool(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getBool() ?? false

        #expect(collectedValue == true, "Collected value should be true")
    }

    @Test("CSVValue as borrowed Bool with invalid values", arguments: ["invalid", "123abc", "yesno"])
    func testCSVValueWithBorrowedBoolTrueWithInvalidValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)

        #expect(throws: CSVError.self) {
            _ = try csvValue.getBool()
        }
    }

    @Test("CSVValue as borrowed Bool with false values", arguments: ["false", "FALSE", "no", "nO", "0", "n", "N"])
    func testCSVValueWithBorrowedBoolWithFalseValues(inputValue: String) throws {
        let bytes = [UInt8](inputValue.utf8)
        let csvValue = TestUtils.createCSVValue(from: bytes, source: .ref)
        let collectedValue = try csvValue.getBool() ?? false

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

        let safeValue = try safeCopy.getString() ?? ""
        #expect(safeValue == inputValue, "Safe copy should have the same value as the original CSVValue")
    }
}
