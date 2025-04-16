import Foundation

public extension FastCSV {
    /// Row Iterator for CSV files
    /// This iterator returns each row as an array of CSVValue.
    /// It is designed to be efficient and reusable, minimizing memory allocations.
    /// - ⚠️ This iterator is not thread-safe. It only should be used in a single-threaded context.
    /// - ⚠️ This iterator will automatically clean up resources after the last row is processed (including when encountering a fatal exception), but the user is responsible for calling cleanup if they choose not to iterate through all rows.
    struct CSVArrayIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVArrayResult

        private var rawIterator: CSVBaseIterator
        private let headerCount: Int
        private var rowNumber: Int

        // Pre-allocated arrays for reuse
        private var valueBuffer: [CSVValue]

        init(rawIterator: CSVBaseIterator, headerCount: Int, skipFirstRow: Bool = false) {
            self.rawIterator = rawIterator
            self.headerCount = headerCount

            // Pre-allocate buffer for values with expected capacity
            if headerCount > 0 {
                // Start with row 2 if we're skipping the first row (headers)
                rowNumber = skipFirstRow ? 1 : 0
                // Pre-allocate with capacity to avoid reallocations
                valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: headerCount)
            } else {
                rowNumber = 0
                valueBuffer = []
            }
        }

        // MARK: IteratorProtocol

        /// Returns the next row as an array of CSVValue
        /// - Returns: A CSVArrayResult containing the row values and any parsing error, or nil if there are no more rows
        /// - Note: This method will automatically clean up resources after processing all rows.
        /// - Note: This method is not thread-safe and should only be used in a single-threaded context.
        public mutating func next() -> CSVArrayResult? {
            // Get raw field buffers from the raw iterator
            guard let result = rawIterator.next() else {
                return nil
            }

            rowNumber += 1
            let fieldCount = result.count

            // Ensure buffer has the right size at initialization and keep it that way
            // If size needs to change, create a new buffer with exact size once
            if valueBuffer.count != fieldCount {
                // Create a new buffer of exactly the right size - more efficient than
                // repeated append/remove operations when sizes differ a lot
                var newBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: fieldCount)

                // Copy over existing values up to the minimum count
                let minCount = Swift.min(valueBuffer.count, fieldCount)
                for i in 0 ..< minCount {
                    newBuffer[i] = valueBuffer[i]
                }
                valueBuffer = newBuffer
            }

            // Now we know valueBuffer.count == fieldCount, update in place
            for i in 0 ..< fieldCount {
                let fieldPointer = result[i]
                valueBuffer[i].update(buffer: fieldPointer.isEmpty ? nil : fieldPointer)
            }

            // Determine the error
            var error = result.parsingError
            if headerCount > 0 && fieldCount != headerCount && error == nil {
                error = CSVError.rowError(
                    row: rowNumber,
                    message: "Row \(rowNumber) has \(fieldCount) columns, expected \(headerCount)."
                )
            }

            return CSVArrayResult(values: valueBuffer, error: error)
        }

        // MARK: Helper Methods

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
        var iterator = try makeArrayIterator()
        defer {
            iterator.cleanup()
        }

        while let result = iterator.next() {
            try callback(result)
        }
    }
}
