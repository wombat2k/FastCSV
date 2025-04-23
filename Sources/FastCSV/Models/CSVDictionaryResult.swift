import Foundation

/// Represents a row of CSV values as a dictionary.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVDictionaryResult objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copyDictionary()` method
/// to create a safely owned copy of the values.
/// - Note: The dictionary keys are the column names, and the values are CSVValue objects.
/// - Note: if the file contains no headers and you did not provide any, the column names will be replaced with a generated name like "column_1", "column_2", etc.
public struct CSVDictionaryResult {
    public let values: [String: CSVValue]
    public let error: CSVError?

    public init(values: [String: CSVValue], error: CSVError?) {
        self.values = values
        self.error = error
    }

    /// Returns a safe copy of the dictionary
    /// - Returns: A new dictionary with copied values
    public func copyDictionary() -> [String: CSVValue] {
        var safeDictionary = [String: CSVValue](minimumCapacity: values.count)

        for (key, value) in values {
            safeDictionary[key] = value.copy()
        }

        return safeDictionary
    }
}

// MARK: - Dictionary-like access

public extension CSVDictionaryResult {
    /// Access a CSV value by key
    subscript(key: String) -> CSVValue? {
        return values[key]
    }
}

// MARK: - Collection protocols

extension CSVDictionaryResult: Collection {
    public typealias Index = Dictionary<String, CSVValue>.Index
    public typealias Element = Dictionary<String, CSVValue>.Element

    public var startIndex: Index { return values.startIndex }
    public var endIndex: Index { return values.endIndex }

    public func index(after i: Index) -> Index {
        return values.index(after: i)
    }

    public subscript(position: Index) -> Element {
        return values[position]
    }

    /// The number of key-value pairs in the dictionary
    public var count: Int { return values.count }

    /// Returns true if the dictionary contains no key-value pairs
    public var isEmpty: Bool { return values.isEmpty }

    /// Returns true if the dictionary contains the specified key
    public func contains(key: String) -> Bool {
        return values[key] != nil
    }

    /// Returns the keys of the dictionary
    public var keys: Dictionary<String, CSVValue>.Keys {
        return values.keys
    }
}
