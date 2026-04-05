import Foundation

/// Represents a row of CSV values as an array.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVArrayResult objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copyArray()` method
/// to create a safely owned copy of the values.
public struct CSVArrayResult {
    public let values: [CSVValue]
    public let error: CSVError?

    /// Returns a safe copy of the array of CSVValue
    /// - Returns: A new array with copied values
    /// - Note: This method is useful for ensuring that the values are not invalidated
    ///   when the underlying buffer is released.
    public func copyArray() -> [CSVValue] {
        return values.map { $0.copy() }
    }
}

// MARK: - Array-like access

extension CSVArrayResult: RandomAccessCollection {
    public typealias Index = Array<CSVValue>.Index
    public typealias Element = CSVValue

    public var startIndex: Index {
        return values.startIndex
    }

    public var endIndex: Index {
        return values.endIndex
    }

    public subscript(position: Index) -> Element {
        return values[position]
    }

    /// The number of values in the array
    public var count: Int {
        return values.count
    }

    /// Returns true if the array contains no values
    public var isEmpty: Bool {
        return values.isEmpty
    }
}
