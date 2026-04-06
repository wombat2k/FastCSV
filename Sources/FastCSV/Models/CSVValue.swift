import Foundation

/// Represents a field value in a CSV file.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVValue objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copy()` method
/// to create a safely owned copy of the value.
public struct CSVValue {
    static let defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// The internal storage mechanism for the value - optimized for smaller enum size
    /// and faster switching logic
    enum ValueSource {
        // Using a simpler enum design to reduce memory overhead
        // and minimize the cost of initialization and switches
        case none
        case ref(UnsafeBufferPointer<UInt8>)
        case own([UInt8])
    }

    /// The underlying storage
    private(set) var valueSource: ValueSource

    /// Create a value directly from a byte buffer (no copy)
    init(buffer: UnsafeBufferPointer<UInt8>?) {
        if let buffer, !buffer.isEmpty {
            valueSource = .ref(buffer)
        } else {
            valueSource = .none
        }
    }

    /// Create a value from owned bytes
    init(bytes: [UInt8]) {
        // Handle empty bytes array
        if bytes.isEmpty {
            valueSource = .none
            return
        }

        valueSource = .own(bytes)
    }

    /// Check if the value is empty. Empty means the field is empty
    /// - Returns: true if the value is empty, false otherwise
    public var isEmpty: Bool {
        if case .none = valueSource {
            return true
        }
        return false
    }

    /// Check if the value is safe to be stored
    /// - Returns: true if the value is safe, false otherwise
    public var isSafe: Bool {
        switch valueSource {
        case .none:
            true
        case .own:
            true
        case .ref:
            false
        }
    }
}

// MARK: - Direct Byte Parsing

private extension CSVValue {
    /// Execute a closure with access to the raw bytes, returning nil for empty values.
    func withRawBytes<T>(_ body: (UnsafeBufferPointer<UInt8>) throws -> T) rethrows -> T? {
        switch valueSource {
        case .none:
            nil
        case let .ref(buffer):
            try body(buffer)
        case let .own(bytes):
            try bytes.withUnsafeBufferPointer { try body($0) }
        }
    }

    /// Parse an integer directly from ASCII bytes without intermediate String allocation.
    /// Handles optional leading sign, overflow checking, and T.min for signed types.
    static func parseInteger<T: FixedWidthInteger>(from bytes: UnsafeBufferPointer<UInt8>) -> T? {
        guard !bytes.isEmpty else { return nil }

        var index = 0
        var negate = false

        if bytes[index] == UInt8(ascii: "-") {
            guard T.isSigned else { return nil }
            negate = true
            index += 1
        } else if bytes[index] == UInt8(ascii: "+") {
            index += 1
        }

        guard index < bytes.count else { return nil }

        // Accumulate using subtraction when negative to correctly handle T.min
        var result: T = 0
        while index < bytes.count {
            let byte = bytes[index]
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
            let digit = T(byte &- UInt8(ascii: "0"))

            let (multiplied, overflowed) = result.multipliedReportingOverflow(by: 10)
            guard !overflowed else { return nil }

            if negate {
                let (subtracted, underflowed) = multiplied.subtractingReportingOverflow(digit)
                guard !underflowed else { return nil }
                result = subtracted
            } else {
                let (added, overflowed) = multiplied.addingReportingOverflow(digit)
                guard !overflowed else { return nil }
                result = added
            }

            index += 1
        }

        return result
    }

    /// Parse a Double directly from ASCII bytes using strtod.
    /// Uses withUnsafeTemporaryAllocation for a stack-friendly null-terminated buffer.
    static func parseDouble(from bytes: UnsafeBufferPointer<UInt8>) -> Double? {
        guard !bytes.isEmpty else { return nil }
        // Reject leading/trailing whitespace to match Swift's Double.init behavior
        if bytes[0] == 0x20 || bytes[0] == 0x09 ||
            bytes[bytes.count - 1] == 0x20 || bytes[bytes.count - 1] == 0x09
        {
            return nil
        }

        return withUnsafeTemporaryAllocation(byteCount: bytes.count + 1, alignment: 1) { temp in
            temp.copyBytes(from: bytes)
            temp[bytes.count] = 0

            let cStr = temp.baseAddress!.assumingMemoryBound(to: CChar.self)
            var endPtr: UnsafeMutablePointer<CChar>?
            let result = strtod(cStr, &endPtr)

            guard let end = endPtr, end == cStr + bytes.count else { return nil }
            return result
        }
    }

    /// Parse a Float directly from ASCII bytes using strtof.
    static func parseFloat(from bytes: UnsafeBufferPointer<UInt8>) -> Float? {
        guard !bytes.isEmpty else { return nil }
        if bytes[0] == 0x20 || bytes[0] == 0x09 ||
            bytes[bytes.count - 1] == 0x20 || bytes[bytes.count - 1] == 0x09
        {
            return nil
        }

        return withUnsafeTemporaryAllocation(byteCount: bytes.count + 1, alignment: 1) { temp in
            temp.copyBytes(from: bytes)
            temp[bytes.count] = 0

            let cStr = temp.baseAddress!.assumingMemoryBound(to: CChar.self)
            var endPtr: UnsafeMutablePointer<CChar>?
            let result = strtof(cStr, &endPtr)

            guard let end = endPtr, end == cStr + bytes.count else { return nil }
            return result
        }
    }
}

// MARK: - Bool Parsing

extension CSVValue {
    /// Parse a Bool directly from ASCII bytes without intermediate String allocation.
    /// Case-insensitive matching using bitwise OR for lowercase conversion.
    static func parseBool(from bytes: UnsafeBufferPointer<UInt8>) -> Bool? {
        switch bytes.count {
        case 1:
            switch bytes[0] {
            case UInt8(ascii: "1"), UInt8(ascii: "y"), UInt8(ascii: "Y"): return true
            case UInt8(ascii: "0"), UInt8(ascii: "n"), UInt8(ascii: "N"): return false
            default: return nil
            }
        case 2:
            if (bytes[0] | 0x20) == UInt8(ascii: "n"),
               (bytes[1] | 0x20) == UInt8(ascii: "o") { return false }
            return nil
        case 3:
            if (bytes[0] | 0x20) == UInt8(ascii: "y"),
               (bytes[1] | 0x20) == UInt8(ascii: "e"),
               (bytes[2] | 0x20) == UInt8(ascii: "s") { return true }
            return nil
        case 4:
            if (bytes[0] | 0x20) == UInt8(ascii: "t"),
               (bytes[1] | 0x20) == UInt8(ascii: "r"),
               (bytes[2] | 0x20) == UInt8(ascii: "u"),
               (bytes[3] | 0x20) == UInt8(ascii: "e") { return true }
            return nil
        case 5:
            if (bytes[0] | 0x20) == UInt8(ascii: "f"),
               (bytes[1] | 0x20) == UInt8(ascii: "a"),
               (bytes[2] | 0x20) == UInt8(ascii: "l"),
               (bytes[3] | 0x20) == UInt8(ascii: "s"),
               (bytes[4] | 0x20) == UInt8(ascii: "e") { return false }
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Non-Optional Accessors (throw on empty or invalid)

public extension CSVValue {
    /// The value as a String using the default quote character. Throws if the field is empty.
    var string: String {
        get throws { try string() }
    }

    /// The value as a String. Throws if the field is empty.
    /// - Parameter quoteChar: The quote character used to wrap field values. Defaults to double quote (`"`).
    func string(quoteChar: UInt8 = UInt8(ascii: "\"")) throws -> String {
        guard let result = try stringIfPresent(quoteChar: quoteChar) else {
            throw CSVError.invalidValueConversion(message: "Expected String but field is empty")
        }
        return result
    }

    /// The value as an Int. Throws if the field is empty or cannot be converted.
    var int: Int {
        get throws {
            guard let result = try intIfPresent else {
                throw CSVError.invalidValueConversion(message: "Expected Int but field is empty")
            }
            return result
        }
    }

    /// The value as a Decimal. Throws if the field is empty or cannot be converted.
    var decimal: Decimal {
        get throws {
            guard let result = try decimalIfPresent else {
                throw CSVError.invalidValueConversion(message: "Expected Decimal but field is empty")
            }
            return result
        }
    }

    /// The value as a Double. Throws if the field is empty or cannot be converted.
    var double: Double {
        get throws {
            guard let result = try doubleIfPresent else {
                throw CSVError.invalidValueConversion(message: "Expected Double but field is empty")
            }
            return result
        }
    }

    /// The value as a Float. Throws if the field is empty or cannot be converted.
    var float: Float {
        get throws {
            guard let result = try floatIfPresent else {
                throw CSVError.invalidValueConversion(message: "Expected Float but field is empty")
            }
            return result
        }
    }

    /// The value as a Bool. Throws if the field is empty or cannot be converted.
    /// Accepts "true"/"yes"/"1"/"y" and "false"/"no"/"0"/"n" (case insensitive).
    var bool: Bool {
        get throws {
            guard let result = try boolIfPresent else {
                throw CSVError.invalidValueConversion(message: "Expected Bool but field is empty")
            }
            return result
        }
    }

    /// The value as a Date. Throws if the field is empty or cannot be converted.
    func date(formatter: DateFormatter? = nil) throws -> Date {
        guard let result = try dateIfPresent(formatter: formatter) else {
            throw CSVError.invalidValueConversion(message: "Expected Date but field is empty")
        }
        return result
    }
}

// MARK: - Optional Accessors (nil on empty, throw on invalid)

public extension CSVValue {
    /// The value as a String using the default quote character, or nil if the field is empty.
    var stringIfPresent: String? {
        get throws { try stringIfPresent() }
    }

    /// The value as a String, or nil if the field is empty.
    /// - Parameter quoteChar: The quote character used to wrap field values. Defaults to double quote (`"`).
    func stringIfPresent(quoteChar: UInt8 = UInt8(ascii: "\"")) throws -> String? {
        guard let str = try getRawString() else {
            return nil
        }
        return processQuotes(str, quoteChar: quoteChar)
    }

    /// The value as an Int, or nil if the field is empty. Throws on invalid conversion.
    var intIfPresent: Int? {
        get throws {
            try fixedWidthIntegerIfPresent()
        }
    }

    /// The value as any FixedWidthInteger type, or nil if the field is empty. Throws on invalid conversion.
    func fixedWidthIntegerIfPresent<T: FixedWidthInteger>() throws -> T? {
        try withRawBytes { bytes in
            guard let result: T = Self.parseInteger(from: bytes) else {
                throw CSVError.invalidValueConversion(
                    message: "Could not convert '\(String(bytes: bytes, encoding: .utf8) ?? "?")' to \(T.self)",
                )
            }
            return result
        }
    }

    /// The value as a Decimal, or nil if the field is empty. Throws on invalid conversion.
    var decimalIfPresent: Decimal? {
        get throws {
            guard let str = try getRawString() else {
                return nil
            }
            guard let decimal = Decimal(string: str) else {
                throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Decimal")
            }
            return decimal
        }
    }

    /// The value as a Double, or nil if the field is empty. Throws on invalid conversion.
    var doubleIfPresent: Double? {
        get throws {
            try withRawBytes { bytes in
                guard let result = Self.parseDouble(from: bytes) else {
                    throw CSVError.invalidValueConversion(
                        message: "Could not convert '\(String(bytes: bytes, encoding: .utf8) ?? "?")' to Double",
                    )
                }
                return result
            }
        }
    }

    /// The value as a Float, or nil if the field is empty. Throws on invalid conversion.
    var floatIfPresent: Float? {
        get throws {
            try withRawBytes { bytes in
                guard let result = Self.parseFloat(from: bytes) else {
                    throw CSVError.invalidValueConversion(
                        message: "Could not convert '\(String(bytes: bytes, encoding: .utf8) ?? "?")' to Float",
                    )
                }
                return result
            }
        }
    }

    /// The value as a Bool, or nil if the field is empty. Throws on invalid conversion.
    /// Accepts "true"/"yes"/"1"/"y" and "false"/"no"/"0"/"n" (case insensitive).
    var boolIfPresent: Bool? {
        get throws {
            try withRawBytes { bytes in
                guard let result = Self.parseBool(from: bytes) else {
                    throw CSVError.invalidValueConversion(
                        message: "Could not convert '\(String(bytes: bytes, encoding: .utf8) ?? "?")' to Bool",
                    )
                }
                return result
            }
        }
    }

    /// The value as a Date, or nil if the field is empty. Throws on invalid conversion.
    func dateIfPresent(formatter: DateFormatter? = nil) throws -> Date? {
        guard let str = try getRawString() else {
            return nil
        }
        let dateFormatter = formatter ?? Self.defaultDateFormatter
        guard let date = dateFormatter.date(from: str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Date")
        }
        return date
    }

    /// Creates a safe copy of this CSVValue that won't be invalidated when the buffer is released
    func copy() -> CSVValue {
        switch valueSource {
        case .none:
            CSVValue(buffer: nil)

        case let .ref(buffer):
            CSVValue(bytes: Array(buffer))

        case .own:
            self
        }
    }

    /// Process quotes in CSV string values
    private func processQuotes(_ str: String, quoteChar: UInt8) -> String {
        let quote = String(UnicodeScalar(quoteChar))

        // If surrounded by quotes, remove them and process escaped quotes
        if str.hasPrefix(quote), str.hasSuffix(quote) {
            // Remove surrounding quotes
            let content = str.dropFirst().dropLast()

            // Replace doubled quotes with single quote (escape sequence)
            return String(content).replacing(quote + quote, with: quote)
        }

        return str
    }

    /// Get the raw string value
    /// - Returns: The string value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    private func getRawString() throws -> String? {
        try withRawBytes { bytes in
            guard let str = String(bytes: bytes, encoding: .utf8) else {
                throw CSVError.invalidValueConversion(message: "Could not convert bytes to string")
            }
            return str
        }
    }

    internal mutating func update(buffer: UnsafeBufferPointer<UInt8>?) {
        if let buffer, !buffer.isEmpty {
            valueSource = .ref(buffer)
        } else {
            valueSource = .none
        }
    }
}
