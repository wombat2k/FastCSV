public extension FastCSV {
    /// Iterator for dictionaries of header keys -> CSVValue
    struct CSVValueDictionaryIterator: IteratorProtocol, Sequence {
        public typealias Element = [String: CSVValue]

        private var valueArrayIterator: CSVValueArrayIterator
        private let headers: [String]

        // Cache of column names to avoid string interpolation in the hot path
        private let columnKeys: [String]

        /// Access the current row's validation error, if any
        public var currentRowError: CSVError? {
            valueArrayIterator.currentRowError
        }

        init(valueArrayIterator: CSVValueArrayIterator, headers: [String]) {
            self.valueArrayIterator = valueArrayIterator
            self.headers = headers

            // Pre-compute column keys once, replacing empty headers with auto-generated column names
            columnKeys = headers.enumerated().map { index, header in
                header.isEmpty ? "column_\(index + 1)" : header // Using 1-based indexing for readability
            }
        }

        /// Cleans up resources used by this iterator and the underlying iterators
        /// Call this method when done iterating to ensure all resources are properly released
        public mutating func cleanup() {
            // Propagate cleanup to the value array iterator which will propagate to the row iterator
            valueArrayIterator.cleanup()
        }

        public mutating func next() -> [String: CSVValue]? {
            guard let values = valueArrayIterator.next() else {
                return nil
            }

            // Create a new dictionary with enough capacity
            var result = [String: CSVValue](minimumCapacity: headers.count)

            // Populate the dictionary directly using column keys (which handle empty headers)
            let count = Swift.min(columnKeys.count, values.count)
            for i in 0 ..< count {
                // Here we use columnKeys which already handles empty headers
                result[columnKeys[i]] = values[i]
            }

            // Handle any extra columns
            if values.count > columnKeys.count {
                for i in columnKeys.count ..< values.count {
                    result["column_\(i + 1)"] = values[i] // Use 1-based indexing for extra columns
                }
            }

            return result
        }
    }

    // MARK: - Convenience Methods

    /// Process the CSV file with a callback for each row as a dictionary
    /// - Parameter callback: Function to process each row
    /// - Note: This method will automatically clean up resources after processing all rows.
    func forEach(_ callback: ([String: CSVValue], CSVError?) throws -> Void) throws {
        var iterator = try makeValueDictionaryIterator()
        defer {
            // Ensure cleanup happens even if processing fails
            iterator.cleanup()
        }

        while let row = iterator.next() {
            try callback(row, iterator.currentRowError)
        }
    }
}
