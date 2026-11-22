#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

/// Decoding state shared by reference across every row of one iteration.
///
/// The column map / quote char / date strategy are row-invariant. `values` is
/// the current row: CSVDecodableIterator sets it before `T(from:)` and clears
/// it afterwards so the parser's reused row buffer stays uniquely referenced.
final class CSVDecoderContext {
    let columnIndexMap: [String: Int]
    let quoteChar: UInt8
    let dateStrategy: CSVDateStrategy

    /// The row currently being decoded. Empty between rows.
    var values: [CSVValue] = []

    init(columnIndexMap: [String: Int], quoteChar: UInt8, dateStrategy: CSVDateStrategy) {
        self.columnIndexMap = columnIndexMap
        self.quoteChar = quoteChar
        self.dateStrategy = dateStrategy
    }
}

/// Reuses one `KeyedDecodingContainer` across rows.
///
/// `KeyedDecodingContainer` wraps its concrete container in a stdlib-internal
/// class box, so building one per row costs a heap allocation per row. The
/// container reads the row through `CSVDecoderContext` rather than capturing
/// it, so the same instance is valid for every row and only needs building
/// once per `Key` type.
///
/// This is a separate object from the context on purpose: the container holds
/// the context strongly, and if the context also held the cache that would be
/// a retain cycle. Breaking it with `unowned` costs ~14% decode time in
/// refcount checks on every field access.
final class CSVKeyedContainerCache {
    let context: CSVDecoderContext

    /// `KeyedDecodingContainer<Key>` for the most recent `Key` type. One slot
    /// is enough: a given `T` asks for the same key type on every row.
    private var cached: Any?

    init(context: CSVDecoderContext) {
        self.context = context
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedDecodingContainer<Key> {
        if let cached = cached as? KeyedDecodingContainer<Key> {
            return cached
        }
        let container = KeyedDecodingContainer(CSVKeyedDecodingContainer<Key>(context: context))
        cached = container
        return container
    }
}

/// Decoder that maps a single CSV row's values to a Decodable type.
/// Uses a column index map (header name -> array index) for O(1) key lookup.
/// Quote stripping happens here via stringIfPresent — the Decoder's job is to
/// bridge CSV format conventions to Swift types.
struct CSVRowDecoder: Decoder {
    // Computed, not stored: keeps the struct a single word (`cache`) so it
    // stays inline in the `any Decoder` existential instead of being boxed.
    var codingPath: [CodingKey] {
        []
    }

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    let cache: CSVKeyedContainerCache

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        cache.container(keyedBy: type)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "CSV rows do not support unkeyed decoding",
            ),
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "CSV rows do not support single value decoding",
            ),
        )
    }
}

// MARK: - Keyed Decoding Container

private struct CSVKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let codingPath: [CodingKey] = []
    let context: CSVDecoderContext

    var allKeys: [Key] {
        context.columnIndexMap.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        context.columnIndexMap[key.stringValue] != nil
    }

    // MARK: - Value Lookup

    private func value(for key: Key) throws -> CSVValue {
        guard let index = context.columnIndexMap[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: [key],
                debugDescription: "No column named '\(key.stringValue)' found in CSV headers",
            ))
        }
        guard index < context.values.count else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Column '\(key.stringValue)' at index \(index) is out of bounds for row with \(context.values.count) fields",
            ))
        }
        return context.values[index]
    }

    /// Get the quote-stripped string for a key. Returns nil for empty fields.
    private func stringValue(for key: Key) throws -> String? {
        let csvValue = try value(for: key)
        return try csvValue.stringIfPresent(quoteChar: context.quoteChar)
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
                debugDescription: "Expected String but found empty field for '\(key.stringValue)'",
            ))
        }
        return result
    }

    // MARK: - Bool

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        try decodeParsed(key: key) { CSVValue.parseBool(from: $0) }
    }

    // MARK: - Int

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    // MARK: - Double

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try decodeParsed(key: key) { CSVValue.parseDouble(from: $0) }
    }

    // MARK: - Float

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try decodeParsed(key: key) { CSVValue.parseFloat(from: $0) }
    }

    // MARK: - Integer Width Variants

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeParsed(key: key) { CSVValue.parseInteger(from: $0) }
    }

    /// Decode a scalar by parsing the quote-stripped bytes directly, skipping
    /// String construction. The String is only built to word the error.
    @inline(__always)
    private func decodeParsed<T>(
        key: Key,
        _ parse: (UnsafeBufferPointer<UInt8>) -> T?,
    ) throws -> T {
        let csvValue = try value(for: key)
        guard let parsed = csvValue.withUnquotedBytes(quoteChar: context.quoteChar, parse) else {
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected \(T.self) but found empty field for '\(key.stringValue)'",
            ))
        }
        guard let result = parsed else {
            let shown = (try? csvValue.stringIfPresent(quoteChar: context.quoteChar)) ?? nil
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Could not convert '\(shown ?? "?")' to \(T.self) for '\(key.stringValue)'",
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
                    debugDescription: "Expected Date but found empty field for '\(key.stringValue)'",
                ))
            }
            let date: Date
            do {
                date = try context.dateStrategy.parse(str)
            } catch {
                throw DecodingError.typeMismatch(Date.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to Date for '\(key.stringValue)'",
                ))
            }
            // swiftlint:disable:next force_cast
            return date as! T
        }

        if type == Decimal.self {
            guard let str = try stringValue(for: key) else {
                throw DecodingError.valueNotFound(Decimal.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Expected Decimal but found empty field for '\(key.stringValue)'",
                ))
            }
            guard let decimal = Decimal(string: str) else {
                throw DecodingError.typeMismatch(Decimal.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to Decimal for '\(key.stringValue)'",
                ))
            }
            // swiftlint:disable:next force_cast
            return decimal as! T
        }

        if type == URL.self {
            let str = try decode(String.self, forKey: key)
            guard let url = URL(string: str) else {
                throw DecodingError.typeMismatch(URL.self, DecodingError.Context(
                    codingPath: [key],
                    debugDescription: "Could not convert '\(str)' to URL for '\(key.stringValue)'",
                ))
            }
            // swiftlint:disable:next force_cast
            return url as! T
        }

        // Fallback: decode from string value via single-value decoder
        guard let str = try stringValue(for: key) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(
                codingPath: [key],
                debugDescription: "Expected \(type) but found empty field for '\(key.stringValue)'",
            ))
        }
        let singleValueDecoder = CSVSingleValueDecoder(value: str, codingPath: [key])
        return try T(from: singleValueDecoder)
    }

    // MARK: - Unsupported

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support nested containers",
        ))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support nested containers",
        ))
    }

    func superDecoder() throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "CSV does not support inheritance decoding",
        ))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: [key],
            debugDescription: "CSV does not support inheritance decoding",
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
            debugDescription: "Single CSV value does not support keyed decoding",
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Single CSV value does not support unkeyed decoding",
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
        let utf8 = Array(value.utf8)
        guard let result = utf8.withUnsafeBufferPointer({ CSVValue.parseBool(from: $0) }) else {
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Bool",
            ))
        }
        return result
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
                debugDescription: "Could not convert '\(value)' to Double",
            ))
        }
        return result
    }

    func decode(_: Float.Type) throws -> Float {
        guard let result = Float(value) else {
            throw DecodingError.typeMismatch(Float.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Could not convert '\(value)' to Float",
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
                debugDescription: "Could not convert '\(value)' to \(T.self)",
            ))
        }
        return result
    }
}
