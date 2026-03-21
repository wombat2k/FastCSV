import Foundation

/// Represents a field value in a CSV file.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVValue objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copy()` method
/// to create a safely owned copy of the value.
public struct CSVValue {
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

public extension CSVValue {
    /// Get the value as a String
    /// - Parameter quoteChar: The quote character used to wrap field values. Defaults to double quote (`"`).
    ///   Required when using a non-standard quote delimiter (e.g. single quote), otherwise quoted fields won't be unwrapped.
    func getString(quoteChar: UInt8 = UInt8(ascii: "\"")) throws -> String? {
        guard let str = try getRawString() else {
            return nil
        }
        return processQuotes(str, quoteChar: quoteChar)
    }

    /// Get the value as an Int
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Returns: The int value, or nil if empty
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
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Returns: The decimal value, or nil if empty
    func getDecimal() throws -> Decimal? {
        guard let str = try getRawString() else {
            return nil
        }

        guard let decimal = Decimal(string: str) else {
            throw CSVError.invalidValueConversion(message: "Could not convert value '\(str)' to decimal")
        }
        return decimal
    }

    /// Get the value as a Double
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Returns: The double value, or nil if empty
    /// - Note: This method uses `Double(str)` for conversion, which may not be as precise as `Decimal`.
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
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Returns: The float value, or nil if empty
    /// - Note: This method uses `Float(str)` for conversion, which may not be as precise as `Double`.
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
    /// - Throws: CSVError.invalidValueConversion if conversion fails
    /// - Returns: true if the value is "true", "yes", "1", "y" (case insensitive)
    ///          false if the value is "false", "no", "0", "n" (case insensitive)
    ///          nil if the value is empty or not convertible
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
            return String(content).replacingOccurrences(of: quote + quote, with: quote)
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
