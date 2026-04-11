import Foundation

public extension FastCSV {
    /// Row Iterator for CSV files
    /// This iterator returns each row as an array of CSVValue.
    /// It is designed to be efficient and reusable, minimizing memory allocations.
    /// ⚠️ - This iterator is not thread-safe. It only should be used in a single-threaded context.
    /// ⚠️ - This iterator will automatically clean up resources after the last row is processed
    /// (including when encountering a fatal exception), but the user is responsible for calling
    /// cleanup if they choose not to iterate through all rows.
    struct CSVArrayIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVArrayResult

        private var rowIterator: CSVRowIterator
        private var rowNumber: Int

        /// Headers extracted or generated during initialization
        public let headers: [String]
        /// Quote character used by the parser (needed by Decodable layer)
        public let quoteChar: UInt8

        /// Pre-allocated arrays for reuse
        private var valueBuffer: [CSVValue]

        /// Buffered first row for hasHeaders:false — yielded on the first call to next()
        private var bufferedFirstRow: [CSVValue]?

        /// Single-pass initializer: the parser reads row 1 during its own init.
        /// We extract headers from it here, then all subsequent next() calls start at row 2.
        init(reader: ByteStreamReader, hasHeaders: Bool, customHeaders: [String] = [], config: CSVParserConfig) throws {
            let finalConfig = config
            quoteChar = finalConfig.delimiter.quoteByte

            var rowIter = CSVRowIterator(reader: reader, config: finalConfig)

            // Get row 1 from the parser (already read during parser init)
            guard let firstRowBytes = rowIter.firstRow.fields else {
                rowIter.cleanup()
                throw CSVError.invalidFile(message: "No data found in the file.")
            }

            if let error = rowIter.firstRow.error {
                rowIter.cleanup()
                throw error
            }

            // Convert row 1 byte arrays to CSVValues
            var firstRowValues = firstRowBytes.map { bytes in
                bytes.isEmpty ? CSVValue(buffer: nil) : CSVValue(bytes: bytes)
            }

            // Remove BOM if present
            firstRowValues = FastCSV.removeUTF8BOMIfPresent(fromRow: firstRowValues)

            // Process headers
            let headerSettings = try FastCSV.processHeaders(
                firstRow: firstRowValues, hasHeaders: hasHeaders, customHeaders: customHeaders,
            )
            headers = headerSettings.headers

            // If row 1 is data (not headers), buffer it for yielding on first next() call
            if !headerSettings.skipFirstRow {
                bufferedFirstRow = firstRowValues
                rowNumber = 0
            } else {
                bufferedFirstRow = nil
                rowNumber = 1
            }

            rowIterator = rowIter

            // Pre-allocate buffer for values with expected capacity
            if !headers.isEmpty {
                valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: headers.count)
            } else {
                valueBuffer = []
            }
        }

        // MARK: IteratorProtocol

        /// Returns the next row as an array of CSVValue
        public mutating func next() -> CSVArrayResult? {
            // Yield the buffered first row if present (hasHeaders: false case)
            if let buffered = bufferedFirstRow {
                bufferedFirstRow = nil
                rowNumber += 1

                if valueBuffer.count != buffered.count {
                    valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: buffered.count)
                }
                for index in 0 ..< buffered.count {
                    valueBuffer[index] = buffered[index]
                }

                var error: CSVError?
                if !headers.isEmpty, buffered.count != headers.count {
                    error = CSVError.rowError(
                        row: rowNumber,
                        message: "Row \(rowNumber) has \(buffered.count) columns, expected \(headers.count).",
                    )
                }

                return CSVArrayResult(values: valueBuffer, error: error)
            }

            // Get raw field buffers from the raw iterator
            guard let result = rowIterator.next() else {
                return nil
            }

            rowNumber += 1
            let fieldCount = result.count

            if valueBuffer.count != fieldCount {
                valueBuffer = [CSVValue](repeating: CSVValue(buffer: nil), count: fieldCount)
            }

            for index in 0 ..< fieldCount {
                let fieldPointer = result[index]
                valueBuffer[index].update(buffer: fieldPointer.isEmpty ? nil : fieldPointer)
            }

            var error = result.parsingError

            if !headers.isEmpty, fieldCount != headers.count, error == nil {
                error = CSVError.rowError(
                    row: rowNumber,
                    message: "Row \(rowNumber) has \(fieldCount) columns, expected \(headers.count).",
                )
            }

            return CSVArrayResult(values: valueBuffer, error: error)
        }

        // MARK: Helper Methods

        /// Cleans up resources used by this iterator and the underlying raw iterator
        public mutating func cleanup() {
            rowIterator.cleanup()
        }

        // MARK: - Convenience Methods

        /// Process the CSV file with a callback for each row as an array of CSVValue
        public mutating func forEach(_ callback: (CSVArrayResult) throws -> Void) throws {
            defer { cleanup() }

            while let result = next() {
                try callback(result)
            }
        }
    }
}
