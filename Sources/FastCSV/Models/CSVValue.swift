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
}

public extension CSVValue {
    /// Get the value as a String
    func getString() throws -> String? {
        guard let str = try getRawString() else {
            return nil
        }
        return processQuotes(str)
    }

    /// Get the value as an Int
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
