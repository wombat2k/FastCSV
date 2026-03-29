import Foundation

/// Represents a field value in a CSV file.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVValue objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copy()` method
/// to create a safely owned copy of the value.
public struct CSVValue {
    private static let defaultDateFormatter: DateFormatter = {
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
    var valueSource: ValueSource

    /// Create a value directly from a byte buffer (no copy)
    init(buffer: UnsafeBufferPointer<UInt8>?) {
        if let buffer = buffer, !buffer.isEmpty {
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
            return true
        case .own:
            return true
        case .ref:
            return false
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
            guard let str = try getRawString() else {
                return nil
            }
            guard let int = Int(str) else {
                throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Int")
            }
            return int
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
    /// - Note: Uses `Double(str)` for conversion, which may not be as precise as `Decimal`.
    var doubleIfPresent: Double? {
        get throws {
            guard let str = try getRawString() else {
                return nil
            }
            guard let double = Double(str) else {
                throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Double")
            }
            return double
        }
    }

    /// The value as a Float, or nil if the field is empty. Throws on invalid conversion.
    /// - Note: Uses `Float(str)` for conversion, which may not be as precise as `Double`.
    var floatIfPresent: Float? {
        get throws {
            guard let str = try getRawString() else {
                return nil
            }
            guard let float = Float(str) else {
                throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Float")
            }
            return float
        }
    }

    /// The value as a Bool, or nil if the field is empty. Throws on invalid conversion.
    /// Accepts "true"/"yes"/"1"/"y" and "false"/"no"/"0"/"n" (case insensitive).
    var boolIfPresent: Bool? {
        get throws {
            guard let str = try getRawString()?.lowercased() else {
                return nil
            }
            switch str {
            case "true", "yes", "1", "y":
                return true
            case "false", "no", "0", "n":
                return false
            default:
                throw CSVError.invalidValueConversion(message: "Could not convert '\(str)' to Bool")
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
            return CSVValue(buffer: nil)

        case let .ref(buffer):
            return CSVValue(bytes: Array(buffer))

        case .own:
            return self
        }
    }

    /// Process quotes in CSV string values
    private func processQuotes(_ str: String, quoteChar: UInt8) -> String {
        let quote = String(UnicodeScalar(quoteChar))

        // If surrounded by quotes, remove them and process escaped quotes
        if str.count >= 2 && str.hasPrefix(quote) && str.hasSuffix(quote) {
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
        switch valueSource {
        case .none:
            return nil
        case let .own(bytes):
            guard let str = String(bytes: bytes, encoding: .utf8) else {
                throw CSVError.invalidValueConversion(message: "Could not convert bytes to string")
            }
            return str
        case let .ref(buffer):
            guard let str = String(bytes: buffer, encoding: .utf8) else {
                throw CSVError.invalidValueConversion(message: "Could not convert bytes to string")
            }
            return str
        }
    }

    internal mutating func update(buffer: UnsafeBufferPointer<UInt8>?) {
        if let buffer = buffer, !buffer.isEmpty {
            valueSource = .ref(buffer)
        } else {
            valueSource = .none
        }
    }
}
