import Foundation

public extension FastCSV {
    /// Row Iterator of CSV values as a dictionary.
    /// This iterator returns each row as a dictionary of String:CSVValue with the key being the header.
    /// It is designed to be efficient and reusable, minimizing memory allocations.
    /// ⚠️ - This iterator is not thread-safe. It only should be used in a single-threaded context.
    /// ⚠️ - This iterator will automatically clean up resources after the last row is processed
    /// (including when encountering a fatal exception), but the user is responsible for calling
    /// cleanup if they choose not to iterate through all rows.
    struct CSVDictionaryIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVDictionaryResult

        private var valueArrayIterator: CSVArrayIterator
        public let headers: [String]

        /// Pre-allocated reusable dictionary for performance
        private var reusableDict: [String: CSVValue]

        init(valueArrayIterator: CSVArrayIterator, headers: [String]) {
            self.valueArrayIterator = valueArrayIterator
            self.headers = headers

            // Pre-allocate dictionary with the exact capacity needed
            reusableDict = Dictionary(minimumCapacity: headers.count)

            // Pre-populate with empty values to establish keys
            for header in headers {
                reusableDict[header] = CSVValue(buffer: nil)
            }
        }

        /// Cleans up resources used by this iterator and the underlying iterators
        /// Call this method when not iterating through all rows.
        public mutating func cleanup() {
            valueArrayIterator.cleanup()
        }

        /// Iterate to the next row of CSV data
        /// - Returns: A CSVDictionaryResult containing the row values as a dictionary, or nil if there are no more rows
        public mutating func next() -> CSVDictionaryResult? {
            guard let arrayResult = valueArrayIterator.next() else {
                return nil
            }

            let values = arrayResult.values
            let error = arrayResult.error

            // Update dictionary values directly - no need to recreate keys
            let count = Swift.min(headers.count, values.count)
            for index in 0 ..< count {
                reusableDict[headers[index]] = values[index]
            }

            // Clear stale values for any headers not covered by this row
            for index in count ..< headers.count {
                reusableDict[headers[index]] = CSVValue(buffer: nil)
            }

            return CSVDictionaryResult(values: reusableDict, error: error)
        }

        // MARK: - Convenience Methods

        /// Process the CSV file with a callback for each row as a dictionary
        /// - Parameter callback: Function to process each row
        /// ⚠️ - This method is not thread-safe. It only should be used in a single-threaded context.
        /// ℹ️ - This method will automatically clean up resources after the last row is processed (including when encountering a fatal exception)
        public mutating func forEach(_ callback: (CSVDictionaryResult) throws -> Void) throws {
            defer {
                cleanup()
            }

            while let result = next() {
                try callback(result)
            }
        }
    }
}
