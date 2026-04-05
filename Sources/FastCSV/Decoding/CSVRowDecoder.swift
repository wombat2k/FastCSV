import Foundation

/// Decoder that maps a single CSV row's values to a Decodable type.
/// Uses a column index map (header name -> array index) for O(1) key lookup.
/// Quote stripping happens here via stringIfPresent — the Decoder's job is to
/// bridge CSV format conventions to Swift types.
struct CSVRowDecoder: Decoder {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    let values: [CSVValue]
    let columnIndexMap: [String: Int]
    let quoteChar: UInt8

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(CSVKeyedDecodingContainer<Key>(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "CSV rows do not support unkeyed decoding"
            )
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "CSV rows do not support single value decoding"
            )
        )
    }
}

// MARK: - Keyed Decoding Container

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let codingPath: [CodingKey] = []
    let decoder: CSVRowDecoder

    var allKeys: [Key] {
        decoder.columnIndexMap.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        decoder.columnIndexMap[key.stringValue] != nil
    }

    // MARK: - Value Lookup

    private func value(for key: Key) throws -> CSVValue {
        guard let index = decoder.columnIndexMap[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: [key],
                debugDescription: "No column named '\(key.stringValue)' found in CSV headers"
            ))
        }
        guard index < decoder.values.count else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Column '\(key.stringValue)' at index \(index) is out of bounds for row with \(decoder.values.count) fields"
            ))
        }
        return decoder.values[index]
    }

    /// Get the quote-stripped string for a key. Returns nil for empty fields.
    private func stringValue(for key: Key) throws -> String? {
        let csvValue = try value(for: key)
        return try csvValue.stringIfPresent(quoteChar: decoder.quoteChar)
    }

    // MARK: - Nil Check

    func decodeNil(forKey key: Key) throws -> Bool {
        let csvValue = try value(for: key)
        return csvValue.isEmpty
    }

    // MARK: - String

    func decode(_: String.Type, forKey key: Key) throws -> String {
        guard let result = try stringValue(for: key) else {
            throw DecodingError.valueNotFound(String.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected String but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Bool

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        guard let str = try stringValue(for: key) else {
            throw DecodingError.valueNotFound(Bool.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected Bool but found empty field for '\(key.stringValue)'"
            ))
        }
        switch str.lowercased() {
        case "true", "yes", "1", "y": return true
        case "false", "no", "0", "n": return false
        default:
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Could not convert '\(str)' to Bool for '\(key.stringValue)'"
            ))
        }
    }

    // MARK: - Int

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try decodeFromString(key: key)
    }

    // MARK: - Double

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try decodeFromString(key: key)
    }

    // MARK: - Float

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try decodeFromString(key: key)
    }

    // MARK: - Integer Width Variants

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeFromString(key: key)
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeFromString(key: key)
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeFromString(key: key)
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeFromString(key: key)
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeFromString(key: key)
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeFromString(key: key)
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeFromString(key: key)
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeFromString(key: key)
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeFromString(key: key)
    }

    /// Decode any LosslessStringConvertible type (Int, Double, Float, all integer widths)
    /// by going through the quote-stripped string.
    private func decodeFromString<T: LosslessStringConvertible>(key: Key) throws -> T {
        guard let str = try stringValue(for: key) else {
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected \(T.self) but found empty field for '\(key.stringValue)'"
            ))
        }
        guard let result = T(str) else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Could not convert '\(str)' to \(T.self) for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Generic Decodable

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // Handle types with direct support
        if type == Date.self {
            guard let str = try stringValue(for: key) else {
                throw DecodingError.valueNotFound(Date.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Expected Date but found empty field for '\(key.stringValue)'"
                ))
            }
            guard let date = CSVValue.defaultDateFormatter.date(from: str) else {
                throw DecodingError.typeMismatch(Date.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to Date for '\(key.stringValue)'"
                ))
            }
            return date as! T
        }

        if type == Decimal.self {
            guard let str = try stringValue(for: key) else {
                throw DecodingError.valueNotFound(Decimal.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Expected Decimal but found empty field for '\(key.stringValue)'"
                ))
            }
            guard let decimal = Decimal(string: str) else {
                throw DecodingError.typeMismatch(Decimal.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to Decimal for '\(key.stringValue)'"
                ))
            }
            return decimal as! T
        }

        if type == URL.self {
            let str = try decode(String.self, forKey: key)
            guard let url = URL(string: str) else {
                throw DecodingError.typeMismatch(URL.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to URL for '\(key.stringValue)'"
                ))
            }
            return url as! T
        }

        // Fallback: decode from string value via single-value decoder
        guard let str = try stringValue(for: key) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected \(type) but found empty field for '\(key.stringValue)'"
            ))
        }
        let singleValueDecoder = CSVSingleValueDecoder(value: str, codingPath: [key])
        return try T(from: singleValueDecoder)
    }

    // MARK: - Unsupported

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support nested containers"
        ))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support nested containers"
        ))
    }

    func superDecoder() throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "CSV does not support inheritance decoding"
        ))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support inheritance decoding"
        ))
    }
}

// MARK: - Single Value Decoder (for generic Decodable fallback)

/// A minimal Decoder that wraps a single string value, allowing custom
/// Decodable types to decode themselves from a CSV field's string content.
private struct CSVSingleValueDecoder: Decoder {
    let value: String
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Single CSV value does not support keyed decoding"
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Single CSV value does not support unkeyed decoding"
        ))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        CSVSingleValueDecodingContainer(value: value, codingPath: codingPath)
    }
}

private struct CSVSingleValueDecodingContainer: SingleValueDecodingContainer {
    let value: String
    let codingPath: [CodingKey]

    func decodeNil() -> Bool {
        false
    }

    func decode(_: String.Type) throws -> String {
        value
    }

    func decode(_: Bool.Type) throws -> Bool {
        switch value.lowercased() {
        case "true", "yes", "1", "y": return true
        case "false", "no", "0", "n": return false
        default:
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Bool"
            ))
        }
    }

    func decode(_: Int.Type) throws -> Int {
        try decodeInteger()
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try decodeInteger()
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try decodeInteger()
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try decodeInteger()
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try decodeInteger()
    }

    func decode(_: UInt.Type) throws -> UInt {
        try decodeInteger()
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeInteger()
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeInteger()
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeInteger()
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeInteger()
    }

    func decode(_: Double.Type) throws -> Double {
        guard let result = Double(value) else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Double"
            ))
        }
        return result
    }

    func decode(_: Float.Type) throws -> Float {
        guard let result = Float(value) else {
            throw DecodingError.typeMismatch(Float.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Float"
            ))
        }
        return result
    }

    func decode<T: Decodable>(_: T.Type) throws -> T {
        // Let the type try to decode itself from this single-value container
        try T(from: CSVSingleValueDecoder(value: value, codingPath: codingPath))
    }

    private func decodeInteger<T: FixedWidthInteger>() throws -> T {
        guard let result = T(value) else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to \(T.self)"
            ))
        }
        return result
    }
}
