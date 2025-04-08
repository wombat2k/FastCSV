public extension FastCSV {
    /// Iterator for CSVValue objects that reference the underlying buffer directly
    struct CSVValueArrayIterator: IteratorProtocol, Sequence {
        public typealias Element = [CSVValue]

        private var rawIterator: CSVRawIterator
        private let headerCount: Int
        private var rowNumber: Int = 0

        // Pre-allocated arrays for reuse
        private var valueBuffer: [CSVValue]

        // The current row's error status
        public private(set) var currentRowError: CSVError?

        init(rawIterator: CSVRawIterator, headerCount: Int) {
            self.rawIterator = rawIterator
            self.headerCount = headerCount

            // Pre-allocate buffer for values with expected capacity
            // Pass nil to the existing buffer initializer for empty values
            valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: Swift.max(headerCount, 20))
        }

        public mutating func next() -> [CSVValue]? {
            // Reset error state for this row
            currentRowError = nil

            // Get raw field buffers from the raw iterator
            guard let fieldPointers = rawIterator.next() else {
                return nil
            }

            rowNumber += 1
            let fieldCount = fieldPointers.count

            // Resize our buffer if needed (only when necessary)
            if valueBuffer.count < fieldCount {
                valueBuffer.append(contentsOf: [CSVValue](repeating: CSVValue(buffer: nil),
                                                          count: fieldCount - valueBuffer.count))
            }

            // Fill the buffer with values created directly from pointers
            for i in 0 ..< fieldCount {
                valueBuffer[i] = CSVValue(buffer: fieldPointers[i].isEmpty ? nil : fieldPointers[i])
            }

            // If buffer is larger than fieldCount, set remaining elements to nil values
            // to avoid returning stale data from previous rows
            if valueBuffer.count > fieldCount {
                // Truncate the buffer to fieldCount
                valueBuffer.removeSubrange(fieldCount ..< valueBuffer.count)
            }

            // Validate row count if headers exist
            if headerCount > 0 && fieldCount != headerCount {
                currentRowError = CSVError.invalidCSV(
                    message: "Row \(rowNumber) has \(fieldCount) columns, expected \(headerCount).")
            }

            // Return the buffer directly - this avoids any copying
            return valueBuffer
        }

        /// Cleans up resources used by this iterator and the underlying raw iterator
        /// Call this method when done iterating to ensure all resources are properly released
        public mutating func cleanup() {
            // Propagate cleanup to the raw iterator to free buffers and close file handles
            rawIterator.cleanup()
        }
    }

    // MARK: - Convenience Methods

    /// Process the CSV file with a callback for each row as an array of CSVValue
    /// - Parameter callback: Function to process each row
    /// - Note: This method will automatically clean up resources after processing all rows.
    func forEach(_ callback: ([CSVValue], CSVError?) throws -> Void) throws {
        var iterator = try makeValueArrayIterator()
        defer {
            // Ensure cleanup happens even if processing fails
            iterator.cleanup()
        }

        while let row = iterator.next() {
            try callback(row, iterator.currentRowError)
        }
    }
}
