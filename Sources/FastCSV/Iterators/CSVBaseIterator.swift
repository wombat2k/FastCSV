import Foundation

struct CSVIteratorResult {
    public let fieldPointers: [UnsafeBufferPointer<UInt8>]
    public let parsingError: CSVError?
}

extension FastCSV {
    /// Zero-copy iterator for CSV rows, returning raw field pointers to the underlying buffer
    struct CSVBaseIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVIteratorResult

        /// Whether parsing has finished
        private var isFinished = false

        /// Position in the current field where parsing started (for fieldPointers)
        private var fieldStartPosition = 0
        /// Collection of field pointers for nextFieldPointers method
        private var fieldPointers = [UnsafeBufferPointer<UInt8>]()

        /// Current position within the read buffer
        var currentPosition = 0
        /// Actual size of the current read data chunk (may be less than readBufferSize, especially at EOF)
        var currentReadBufferSize = 0
        /// Pointer to the current byte array being processed
        var currentBytes: UnsafePointer<UInt8>?
        /// Current buffer of data read from file
        private var currentReadBuffer: Data?

        /// File handle to read from
        private let fileHandle: FileHandle
        /// CSV delimiter configuration
        private let delimiter: Delimiter
        /// Maximum size of buffer chunks to request when reading from file
        private let readBufferSize: Int

        // Add a property to store any error encountered during parsing
        private(set) var parsingError: CSVError?

        // Add a property to track the current row number
        private var currentRowNumber = 1

        /// Initialize a CSVIterator for parsing a CSV file with a FileHandle
        /// - Parameters:
        ///   - fileHandle: FileHandle to read CSV data from
        ///   - skipFirstRow: Whether to skip the first row during iteration (default: true)
        ///   - config: Configuration options for CSV parsing
        init(fileHandle: FileHandle, skipFirstRow: Bool = true, columnCount: Int = 0, config: CSVParserConfig) {
            self.fileHandle = fileHandle
            delimiter = config.delimiter
            readBufferSize = config.readBufferSize

            // Pre-allocate field pointers based on known column count
            // Only reserve capacity if we know the actual column count
            if columnCount > 0 {
                fieldPointers.reserveCapacity(columnCount)
            }
            // When columnCount is 0, we'll let the array grow naturally based on the CSV content

            // Load initial data
            loadNextChunkIfNeeded()

            // Skip the first row if requested
            if skipFirstRow {
                _ = nextFieldPointers()
                currentRowNumber = 2
            }
        }

        // Simple synchronous chunk loading
        private mutating func loadNextChunkIfNeeded() {
            if currentPosition >= currentReadBufferSize || currentReadBuffer == nil {
                // Release previous chunk data
                currentReadBuffer = nil

                do {
                    if let newData = try fileHandle.read(upToCount: readBufferSize), !newData.isEmpty {
                        currentReadBuffer = newData
                        currentReadBufferSize = newData.count
                        currentPosition = 0

                        // Create safe pointer to bytes
                        currentBytes = newData.withUnsafeBytes { pointer in
                            pointer.bindMemory(to: UInt8.self).baseAddress
                        }
                    } else {
                        // No more data
                        handleEndOfFile()
                    }
                } catch {
                    handleEndOfFile()
                }
            }
        }

        public mutating func next() -> CSVIteratorResult? {
            return nextFieldPointers()
        }

        // Enhanced cleanup for background I/O resources
        public mutating func cleanup() {
            // Close file handle if it's still open
            try? fileHandle.close()
        }

        public mutating func nextFieldPointers() -> CSVIteratorResult? {
            // Handle finished state
            if isFinished {
                return nil
            }

            // Clear any previous parsing error before starting a new row
            parsingError = nil

            // Reuse the field pointers array by setting count to 0 instead of recreating
            fieldPointers.removeAll(keepingCapacity: true)
            fieldStartPosition = currentPosition

            // State tracking for quotes
            var inQuote = false

            // Get the maximum allowed column count (0 means unlimited)
            let maxColumns = fieldPointers.capacity

            // Keep track of whether we've exceeded the column limit
            var exceededColumnLimit = false

            // Parse until we find a complete row
            while true {
                loadNextChunkIfNeeded()

                if isFinished {
                    // Process any final field at EOF if needed
                    if currentPosition > fieldStartPosition && currentBytes != nil {
                        // Only add the field if we haven't exceeded the column limit
                        if maxColumns == 0 || fieldPointers.count < maxColumns {
                            let fieldPointer = createFieldPointer(
                                from: fieldStartPosition,
                                to: currentPosition,
                                in: currentBytes!
                            )
                            fieldPointers.append(fieldPointer)
                        } else if !exceededColumnLimit {
                            // Set the error but only once per row
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(fieldPointers.count + 1), expected \(maxColumns)."
                            )
                            exceededColumnLimit = true
                        }
                        // No need to add additional fields when limit is exceeded
                    }
                    return fieldPointers.isEmpty ? nil : CSVIteratorResult(fieldPointers: fieldPointers, parsingError: parsingError)
                }

                guard let bytes = currentBytes else {
                    return nil
                }

                // Process the current chunk to find field boundaries
                while currentPosition < currentReadBufferSize {
                    let byte = bytes[currentPosition]

                    // Handle quote character
                    if byte == delimiter.value {
                        // Critical fix: Only treat as opening quote if at the start of a field and not in a quoted context
                        if !inQuote && currentPosition == fieldStartPosition {
                            // Opening quote at start of field
                            inQuote = true
                            // We want to keep the quote in the field to properly detect quoted fields later
                            currentPosition += 1
                            continue
                        } else if inQuote {
                            // Check for escaped quote (double quote) inside quoted field
                            if currentPosition + 1 < currentReadBufferSize && bytes[currentPosition + 1] == delimiter.value {
                                // Skip one of the quotes, keeping the other in the field
                                currentPosition += 2
                                continue
                            } else {
                                // Closing quote - need to find the field/row delimiter
                                inQuote = false
                                currentPosition += 1
                                continue
                            }
                        } else {
                            // Handle quote that's not at the start of the field as a normal character
                            currentPosition += 1
                            continue
                        }
                    } else if !inQuote && byte == delimiter.field {
                        // End of field - create a pointer to the current field

                        // Only add the field if we haven't exceeded the column limit
                        if maxColumns == 0 || fieldPointers.count < maxColumns {
                            if currentPosition > fieldStartPosition {
                                let fieldPointer = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: currentPosition,
                                    in: bytes
                                )
                                fieldPointers.append(fieldPointer)
                            } else {
                                // Empty field
                                fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
                            }
                        } else if !exceededColumnLimit {
                            // Set the error but only once per row
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(fieldPointers.count + 1), expected \(maxColumns)."
                            )
                            exceededColumnLimit = true
                            // Once we exceed the column limit, we don't create more field pointers
                        }

                        // Update for next field
                        currentPosition += 1
                        fieldStartPosition = currentPosition
                    } else if !inQuote && byte == delimiter.row {
                        // End of row - finalize the current field

                        // Only add the field if we haven't exceeded the column limit
                        if maxColumns == 0 || fieldPointers.count < maxColumns {
                            if currentPosition > fieldStartPosition {
                                let fieldPointer = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: currentPosition,
                                    in: bytes
                                )
                                fieldPointers.append(fieldPointer)
                            } else {
                                // Empty field at end of row
                                fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
                            }
                        } else if !exceededColumnLimit {
                            // Set the error but only once per row
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(fieldPointers.count + 1), expected \(maxColumns)."
                            )
                            exceededColumnLimit = true
                            // Don't add more fields after exceeding the limit
                        }

                        // Move past the row delimiter
                        currentPosition += 1

                        // Handle CR+LF sequence
                        if byte == UInt8(ascii: "\r") && currentPosition < currentReadBufferSize &&
                            bytes[currentPosition] == UInt8(ascii: "\n")
                        {
                            currentPosition += 1
                        }

                        fieldStartPosition = currentPosition

                        // Increment row number after processing a complete row
                        let result = CSVIteratorResult(fieldPointers: fieldPointers, parsingError: parsingError)
                        currentRowNumber += 1
                        return result
                    } else {
                        // Normal character - just advance
                        currentPosition += 1
                    }
                }
            }
        }

        // Helper to handle end of file conditions
        private mutating func handleEndOfFile() {
            // Handle the last field if we're in the middle of one
            if currentPosition > fieldStartPosition && currentBytes != nil {
                // We have a partial field at EOF that needs to be captured
                let bytes = currentBytes!
                let fieldPointer = createFieldPointer(
                    from: fieldStartPosition,
                    to: currentPosition,
                    in: bytes
                )
                fieldPointers.append(fieldPointer)

                // Reset for next time
                fieldStartPosition = currentPosition
            }

            // Set parser state to finished
            isFinished = true
        }

        // Helper method to create a field pointer
        @inline(__always) private func createFieldPointer(from startPosition: Int, to endPosition: Int, in bytes: UnsafePointer<UInt8>) -> UnsafeBufferPointer<UInt8> {
            let length = endPosition - startPosition
            return UnsafeBufferPointer(
                start: bytes.advanced(by: startPosition),
                count: length
            )
        }

        /// Iterates through all rows in the CSV file and applies the given closure to each row of raw buffer pointers.
        /// - Parameter body: The closure to apply to each row, where the row is represented as a CSVIteratorResult.
        /// - Note: This method will automatically clean up resources after processing all rows.
        mutating func forEach(_ body: (CSVIteratorResult) -> Void) {
            // Process each row and call the provided closure
            while let result = next() {
                body(result)
            }

            // Ensure resources are cleaned up after iteration
            if isFinished {
                cleanup()
            }
        }
    }
}
