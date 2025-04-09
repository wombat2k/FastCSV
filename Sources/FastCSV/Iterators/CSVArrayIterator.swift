import Foundation

public extension FastCSV {
    /// Iterator for CSVValue objects that reference the underlying buffer directly
    struct CSVArrayIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVArrayResult

        private var rawIterator: CSVBaseIterator
        private let headerCount: Int
        private var rowNumber: Int

        // Pre-allocated arrays for reuse
        private var valueBuffer: [CSVValue]

        init(rawIterator: CSVBaseIterator, headerCount: Int) {
            self.rawIterator = rawIterator
            self.headerCount = headerCount

            // Pre-allocate buffer for values with expected capacity
            // Pass nil to the existing buffer initializer for empty values
            if headerCount > 0 {
                rowNumber = 1
                // Pre-allocate the buffer with the expected header count
                // This avoids reallocation in the hot path
                valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: headerCount)
            } else {
                rowNumber = 0
                valueBuffer = []
            }
        }

        public mutating func next() -> CSVArrayResult? {
            // Get raw field buffers from the raw iterator
            guard let result = rawIterator.next() else {
                return nil
            }

            let fieldPointers = result.fieldPointers
            let parsingError = result.parsingError

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

            // Prepare the values for return
            let values = Array(valueBuffer[0 ..< fieldCount])

            // Determine the error - either from parsing or column count mismatch
            var error = parsingError

            // Validate row count
            if headerCount > 0 && fieldCount != headerCount && error == nil {
                error = CSVError.rowError(
                    row: rowNumber,
                    message: "Row \(rowNumber) has \(fieldCount) columns, expected \(headerCount)."
                )
            }

            // Return the CSVArrayResult with values and error
            return CSVArrayResult(values: values, error: error)
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
    func forEach(_ callback: (CSVArrayResult) throws -> Void) throws {
        var iterator = try makeValueArrayIterator()
        defer {
            // Ensure cleanup happens even if processing fails
            iterator.cleanup()
        }

        while let result = iterator.next() {
            try callback(result)
        }
    }
}
