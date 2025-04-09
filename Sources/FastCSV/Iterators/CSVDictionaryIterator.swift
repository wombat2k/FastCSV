import Foundation

public extension FastCSV {
    /// Iterator for dictionaries of header keys -> CSVValue
    struct CSVDictionaryIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVDictionaryResult

        private var valueArrayIterator: CSVArrayIterator
        private let headers: [String]

        init(valueArrayIterator: CSVArrayIterator, headers: [String]) {
            self.valueArrayIterator = valueArrayIterator
            self.headers = headers
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

            // Create a new dictionary with enough capacity
            var resultDict = [String: CSVValue](minimumCapacity: headers.count)

            // Populate the dictionary directly using headers (empty headers already handled in FastCSV)
            let count = Swift.min(headers.count, values.count)
            for i in 0 ..< count {
                resultDict[headers[i]] = values[i]
            }

            // Handle any extra columns
            if values.count > headers.count {
                for i in headers.count ..< values.count {
                    resultDict["column_\(i + 1)"] = values[i] // Use 1-based indexing for extra columns
                }
            }

            return CSVDictionaryResult(values: resultDict, error: error)
        }
    }

    // MARK: - Convenience Methods

    /// Process the CSV file with a callback for each row as a dictionary
    /// - Parameter callback: Function to process each row
    /// - Note: This method will automatically clean up resources after processing all rows.
    func forEach(_ callback: (CSVDictionaryResult) throws -> Void) throws {
        var iterator = try makeValueDictionaryIterator()
        defer {
            // Ensure cleanup happens even if processing fails
            iterator.cleanup()
        }

        while let result = iterator.next() {
            try callback(result)
        }
    }
}
