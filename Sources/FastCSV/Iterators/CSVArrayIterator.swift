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

        // Direct storage for CSVResult to avoid copying
        private var resultValues: [CSVValue]?

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

            rowNumber += 1

            // Use the optimized count property instead of array.count
            let fieldCount = result.count

            // Fast path for when headerCount matches fieldCount
            // This avoids any array operations when column count is stable
            if headerCount > 0 && valueBuffer.count == fieldCount {
                // Reuse the existing values directly
                for i in 0 ..< fieldCount {
                    let fieldPointer = result[i]
                    valueBuffer[i] = CSVValue(buffer: fieldPointer.isEmpty ? nil : fieldPointer)
                }

                // Determine if there's an error
                let error = result.parsingError

                // Return directly, avoiding the array copy
                return CSVArrayResult(values: valueBuffer, error: error)
            }

            // Slow path for when we need to resize

            // Resize our buffer if needed
            if valueBuffer.count < fieldCount {
                // Avoid append(contentsOf:) as it does bounds checking
                // and can trigger expensive copy-on-write operations
                let currentCount = valueBuffer.count
                valueBuffer.reserveCapacity(fieldCount)

                // Add individual elements which can be more efficient
                for _ in currentCount ..< fieldCount {
                    valueBuffer.append(CSVValue(buffer: nil))
                }
            }

            // Fill the buffer with values created directly from pointers
            for i in 0 ..< fieldCount {
                let fieldPointer = result[i]
                valueBuffer[i] = CSVValue(buffer: fieldPointer.isEmpty ? nil : fieldPointer)
            }

            // Truncate if needed using more efficient method
            if valueBuffer.count > fieldCount {
                valueBuffer = Array(valueBuffer[0 ..< fieldCount])
            }

            // Determine the error - either from parsing or column count mismatch
            var error = result.parsingError

            // Validate row count
            if headerCount > 0 && fieldCount != headerCount && error == nil {
                error = CSVError.rowError(
                    row: rowNumber,
                    message: "Row \(rowNumber) has \(fieldCount) columns, expected \(headerCount)."
                )
            }

            // Return the CSVArrayResult with values and error
            return CSVArrayResult(values: valueBuffer, error: error)
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
            iterator.cleanup()
        }

        while let result = iterator.next() {
            try callback(result)
        }
    }
}
