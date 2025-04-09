import Foundation

/// Represents a row of CSV values as an array.
/// This type efficiently handles the raw bytes without unnecessary copying.
/// ⚠️ Warning: CSVArrayResult objects may contain references to the underlying CSV buffer.
/// If you need to store values beyond the lifetime of the iterator, use the `copyArray()` method
/// to create a safely owned copy of the values.
public struct CSVArrayResult {
    public let values: [CSVValue]
    public let error: CSVError?

    public init(values: [CSVValue], error: CSVError?) {
        self.values = values
        self.error = error
    }

    /// Returns a safe copy of the array
    /// - Returns: A new array with copied values
    /// - Note: This method is useful for ensuring that the values are not invalidated
    ///   when the underlying buffer is released.
    public func copyArray() -> [CSVValue] {
        return values.map { $0.copy() }
    }
}
