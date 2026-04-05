import Foundation

/// Collects encoded field values as strings, keyed by CodingKey.stringValue.
/// Reference type so the KeyedEncodingContainer can mutate it.
final class EncodedRowStorage {
    /// Ordered keys as encountered during encoding. First encode call defines column order.
    var keys: [String] = []
    /// Key -> string value. Empty string represents nil/empty fields.
    var values: [String: String] = [:]
    let config: CSVWriterConfig

    init(config: CSVWriterConfig) {
        self.config = config
    }

    func set(_ value: String?, forKey key: String) {
        if values[key] == nil {
            keys.append(key)
        }
        values[key] = value ?? ""
    }
}

/// Encoder that collects an Encodable struct's properties into ordered string values.
/// Used internally by CSVWriter to serialize each row.
struct CSVRowEncoder: Encoder {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]
    let storage: EncodedRowStorage

    func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(CSVKeyedEncodingContainer<Key>(storage: storage))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("CSV rows do not support unkeyed encoding")
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("CSV rows do not support single value encoding")
    }
}

// MARK: - Keyed Encoding Container

private struct CSVKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let codingPath: [CodingKey] = []
    let storage: EncodedRowStorage

    // MARK: - String

    mutating func encode(_ value: String, forKey key: Key) throws {
        storage.set(value, forKey: key.stringValue)
    }

    // MARK: - Bool

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        storage.set(value ? "true" : "false", forKey: key.stringValue)
    }

    // MARK: - Numeric Types

    mutating func encode(_ value: Int, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        storage.set(String(value), forKey: key.stringValue)
    }

    // MARK: - Nil

    mutating func encodeNil(forKey key: Key) throws {
        storage.set(nil, forKey: key.stringValue)
    }

    // MARK: - Optional Handling

    // Swift's default encodeIfPresent does nothing for nil, which means
    // the key never gets registered. We override to always store the key
    // so that nil Optional fields produce empty CSV columns.

    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        storage.set(value, forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        storage.set(value.map { $0 ? "true" : "false" }, forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        storage.set(value.map(String.init), forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        storage.set(value.map { String($0) }, forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        storage.set(value.map { String($0) }, forKey: key.stringValue)
    }

    mutating func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
        guard let value else {
            storage.set(nil, forKey: key.stringValue)
            return
        }
        try encode(value, forKey: key)
    }

    // MARK: - Generic Encodable

    mutating func encode(_ value: some Encodable, forKey key: Key) throws {
        if let date = value as? Date {
            storage.set(storage.config.dateFormatter.string(from: date), forKey: key.stringValue)
        } else if let decimal = value as? Decimal {
            storage.set("\(decimal)", forKey: key.stringValue)
        } else if let url = value as? URL {
            storage.set(url.absoluteString, forKey: key.stringValue)
        } else {
            let singleEncoder = CSVSingleValueEncoder(config: storage.config)
            try value.encode(to: singleEncoder)
            storage.set(singleEncoder.result, forKey: key.stringValue)
        }
    }

    // MARK: - Unsupported

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey _: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("CSV does not support nested containers")
    }

    mutating func nestedUnkeyedContainer(forKey _: Key) -> UnkeyedEncodingContainer {
        fatalError("CSV does not support nested containers")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("CSV does not support inheritance encoding")
    }

    mutating func superEncoder(forKey _: Key) -> Encoder {
        fatalError("CSV does not support inheritance encoding")
    }
}

// MARK: - Single Value Encoder (for generic Encodable fallback)

/// A minimal Encoder that captures a single value as a string, allowing custom
/// Encodable types to encode themselves into a CSV field.
private final class CSVSingleValueEncoder: Encoder {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]
    let config: CSVWriterConfig
    var result: String = ""

    init(config: CSVWriterConfig) {
        self.config = config
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("Single CSV value does not support keyed encoding")
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Single CSV value does not support unkeyed encoding")
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        CSVSingleValueEncodingContainer(encoder: self)
    }
}

private struct CSVSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: CSVSingleValueEncoder
    let codingPath: [CodingKey] = []

    mutating func encodeNil() throws {
        encoder.result = ""
    }

    mutating func encode(_ value: String) throws {
        encoder.result = value
    }

    mutating func encode(_ value: Bool) throws {
        encoder.result = value ? "true" : "false"
    }

    mutating func encode(_ value: Int) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Int8) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Int16) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Int32) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Int64) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: UInt) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: UInt8) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: UInt16) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: UInt32) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: UInt64) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Double) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: Float) throws {
        encoder.result = String(value)
    }

    mutating func encode(_ value: some Encodable) throws {
        let nested = CSVSingleValueEncoder(config: encoder.config)
        try value.encode(to: nested)
        encoder.result = nested.result
    }
}
