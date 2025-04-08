import Foundation

/// Represents a field value in a CSV file.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVValue objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copy()` method
/// to create a safely owned copy of the value.
public struct CSVValue {
    /// The internal storage mechanism for the value
    private enum ValueSource {
        case empty
        case reference(UnsafeBufferPointer<UInt8>)
        case owned([UInt8])
    }

    /// The underlying storage
    private let valueSource: ValueSource

    /// Create a value directly from a byte buffer (no copy)
    init(buffer: UnsafeBufferPointer<UInt8>?) {
        if let buffer = buffer, !buffer.isEmpty {
            valueSource = .reference(buffer)
        } else {
            valueSource = .empty
        }
    }

    /// Create a value from owned bytes
    init(bytes: [UInt8]) {
        // Handle empty bytes array
        if bytes.isEmpty {
            valueSource = .empty
            return
        }

        valueSource = .owned(bytes)
    }

    /// Check if the value is empty. Empty means the field as empty
    /// - Returns: true if the value is empty, false otherwise
    public var isEmpty: Bool {
        if case .empty = valueSource {
            return true
        }
        return false
    }
}

public extension CSVValue {
    /// Get the value as a String, with quotes processed
    /// - Returns: The string value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    func getString() throws -> String? {
        guard let str = try getRawString() else {
            return nil
        }
        return processQuotes(str)
    }

    /// Get the value as an Int
    /// - Returns: The integer value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    func getInt() throws -> Int? {
        guard let str = try getRawString() else {
            return nil
        }

        guard let int = Int(str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert \(str) to int")
        }
        return int
    }

    /// Get the value as a Decimal
    /// - Returns: The decimal value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    func getDecimal() throws -> Decimal? {
        guard let str = try getRawString() else {
            return nil
        }

        guard let decimal = Decimal(string: str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert value to decimal")
        }
        return decimal
    }

    /// Get the value as a Double
    /// - Returns: The double value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    ///
    /// ⚠️ This method may result in precision loss. Use `getDecimal()` for better precision.
    func getDouble() throws -> Double? {
        guard let str = try getRawString() else {
            return nil
        }

        guard let double = Double(str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert \(str) to double")
        }
        return double
    }

    /// Get the value as a Float
    /// - Returns: The float value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    ///
    /// ⚠️ This method may result in precision loss. Use `getDecimal()` for better precision.
    func getFloat() throws -> Float? {
        guard let str = try getRawString() else {
            return nil
        }

        guard let float = Float(str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert \(str) to float")
        }
        return float
    }

    /// Get the value as a Bool
    /// - Returns: The boolean value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Note: This method accepts various string representations of boolean values. The comparison is case-insensitive.
    ///     - Supported values:
    ///         - "true", "yes", "1", "y" are considered true
    ///         - "false", "no", "0", "n" are considered false
    ///     - Any other value will throw an error
    func getBool() throws -> Bool? {
        guard let str = try getRawString()?.lowercased() else {
            return nil
        }

        switch str {
        case "true", "yes", "1", "y":
            return true
        case "false", "no", "0", "n":
            return false
        default:
            throw CSVError.invalidValueConversion(message: "Could not convert \(str) to Bool")
        }
    }

    /// Get the value as a Date
    /// - Parameters:
    ///   - formatter: Optional DateFormatter to use for conversion. If nil, a default formatter with "yyyy-MM-dd" format is used.
    /// - Returns: The date value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Note: The default date format is "yyyy-MM-dd". If you need a different format, provide a custom DateFormatter.
    func getDate(formatter: DateFormatter? = nil) throws -> Date? {
        guard let str = try getRawString() else {
            return nil
        }

        let dateFormatter = formatter ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        guard let date = dateFormatter.date(from: str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert \(str) to Date")
        }
        return date
    }

    /// Creates a safe copy of this CSVValue that won't be invalidated when the buffer is released
    /// - Returns: A new CSVValue containing its own copy of the data
    func copy() -> CSVValue {
        switch valueSource {
        case .empty:
            return CSVValue(buffer: nil)

        case let .reference(buffer):
            return CSVValue(bytes: Array(buffer))

        case .owned:
            return self
        }
    }

    /// Process quotes in CSV string values
    private func processQuotes(_ str: String) -> String {
        // If surrounded by quotes, remove them and process escaped quotes
        if str.count >= 2 && str.hasPrefix("\"") && str.hasSuffix("\"") {
            // Remove surrounding quotes
            let content = str.dropFirst().dropLast()

            // Replace "" with " for escaped quotes
            return String(content).replacingOccurrences(of: "\"\"", with: "\"")
        }

        return str
    }

    /// Get the raw string value
    /// - Returns: The string value, or nil if empty
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    private func getRawString() throws -> String? {
        switch valueSource {
        case .empty:
            return nil
        case let .owned(bytes):
            guard let str = String(bytes: bytes, encoding: .utf8) else {
                throw CSVError.invalidValueConversion(message: "Could not convert bytes to string")
            }
            return str
        case let .reference(buffer):
            guard let str = String(bytes: buffer, encoding: .utf8) else {
                throw CSVError.invalidValueConversion(message: "Could not convert bytes to string")
            }
            return str
        }
    }
}
