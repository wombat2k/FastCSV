import Foundation

public extension FastCSV {
    /// Iterator for dictionaries of header keys -> CSVValue
    struct CSVDictionaryIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVDictionaryResult

        private var valueArrayIterator: CSVArrayIterator
        private let headers: [String]

        // Pre-allocated reusable dictionary for performance
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
        /// Call this method when done iterating to ensure all resources are properly released
        public mutating func cleanup() {
            // Propagate cleanup to the value array iterator which will propagate to the row iterator
            valueArrayIterator.cleanup()
        }

        public mutating func next() -> CSVDictionaryResult? {
            guard let arrayResult = valueArrayIterator.next() else {
                return nil
            }

            let values = arrayResult.values
            let error = arrayResult.error

            // Update dictionary values directly - no need to recreate keys
            let count = Swift.min(headers.count, values.count)
            for i in 0 ..< count {
                reusableDict[headers[i]] = values[i]
            }

            // Since dictionaries are value types, return a copy for the caller
            return CSVDictionaryResult(values: reusableDict, error: error)
        }
    }

    // MARK: - Convenience Methods

    /// Process the CSV file with a callback for each row as a dictionary
    /// - Parameter callback: Function to process each row
    /// - Note: This method will automatically clean up resources after processing all rows.
    func forEach(_ callback: (CSVDictionaryResult) throws -> Void) throws {
        var iterator = try makeDictionaryIterator()
        defer {
            // Ensure cleanup happens even if processing fails
            iterator.cleanup()
        }

        while let result = iterator.next() {
            try callback(result)
        }
    }
}
