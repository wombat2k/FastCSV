import Foundation

/// Decoder that maps a single CSV row's values to a Decodable type.
/// Uses a column index map (header name -> array index) for O(1) key lookup,
/// and delegates type conversion to CSVValue's existing methods.
struct CSVRowDecoder: Decoder {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    let values: [CSVValue]
    let columnIndexMap: [String: Int]
    let quoteChar: UInt8

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
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

    // MARK: - Nil Check

    func decodeNil(forKey key: Key) throws -> Bool {
        let csvValue = try value(for: key)
        return csvValue.isEmpty
    }

    // MARK: - String

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let csvValue = try value(for: key)
        guard let result = try csvValue.getString(quoteChar: decoder.quoteChar) else {
            throw DecodingError.valueNotFound(String.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected String but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Bool

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let csvValue = try value(for: key)
        guard let result = try csvValue.getBool() else {
            throw DecodingError.valueNotFound(Bool.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected Bool but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Int

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let csvValue = try value(for: key)
        guard let result = try csvValue.getInt() else {
            throw DecodingError.valueNotFound(Int.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected Int but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Double

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let csvValue = try value(for: key)
        guard let result = try csvValue.getDouble() else {
            throw DecodingError.valueNotFound(Double.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected Double but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Float

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        let csvValue = try value(for: key)
        guard let result = try csvValue.getFloat() else {
            throw DecodingError.valueNotFound(Float.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected Float but found empty field for '\(key.stringValue)'"
            ))
        }
        return result
    }

    // MARK: - Integer Width Variants

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeIntegerWidth(key: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeIntegerWidth(key: key)
    }

    private func decodeIntegerWidth<T: FixedWidthInteger>(key: Key) throws -> T {
        let csvValue = try value(for: key)
        guard let str = try csvValue.getString(quoteChar: decoder.quoteChar) else {
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
        // Handle types with direct CSVValue support
        if type == Date.self {
            let csvValue = try value(for: key)
            guard let result = try csvValue.getDate() else {
                throw DecodingError.valueNotFound(Date.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Expected Date but found empty field for '\(key.stringValue)'"
                ))
            }
            return result as! T
        }

        if type == Decimal.self {
            let csvValue = try value(for: key)
            guard let result = try csvValue.getDecimal() else {
                throw DecodingError.valueNotFound(Decimal.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Expected Decimal but found empty field for '\(key.stringValue)'"
                ))
            }
            return result as! T
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
        let csvValue = try value(for: key)
        guard let str = try csvValue.getString(quoteChar: decoder.quoteChar) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected \(type) but found empty field for '\(key.stringValue)'"
            ))
        }
        let singleValueDecoder = CSVSingleValueDecoder(value: str, codingPath: [key])
        return try T(from: singleValueDecoder)
    }

    // MARK: - Unsupported

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
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

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
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

    func decodeNil() -> Bool { false }

    func decode(_ type: String.Type) throws -> String { value }

    func decode(_ type: Bool.Type) throws -> Bool {
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

    func decode(_ type: Int.Type) throws -> Int { try decodeInteger() }
    func decode(_ type: Int8.Type) throws -> Int8 { try decodeInteger() }
    func decode(_ type: Int16.Type) throws -> Int16 { try decodeInteger() }
    func decode(_ type: Int32.Type) throws -> Int32 { try decodeInteger() }
    func decode(_ type: Int64.Type) throws -> Int64 { try decodeInteger() }
    func decode(_ type: UInt.Type) throws -> UInt { try decodeInteger() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeInteger() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeInteger() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeInteger() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeInteger() }

    func decode(_ type: Double.Type) throws -> Double {
        guard let result = Double(value) else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Double"
            ))
        }
        return result
    }

    func decode(_ type: Float.Type) throws -> Float {
        guard let result = Float(value) else {
            throw DecodingError.typeMismatch(Float.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Float"
            ))
        }
        return result
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
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
