import Foundation

extension FastCSV {
    /// Parser for CSV data with a fixed number of columns, supporting quotes
    struct FixedColumnParser: CSVParser {
        /// Number of columns to parse
        private let columnCount: Int
        /// Storage for parsed fields
        private let storage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>
        /// File chunk reader
        private var chunkReader: FileChunkReader
        /// CSV delimiter configuration
        private let delimiter: Delimiter
        /// Current row number being processed
        private var currentRowNumber: Int = 1
        /// Current parsing error, if any
        private var parsingError: CSVError?
        /// Current field start position
        private var fieldStartPosition: Int = 0

        init(columnCount: Int, fileHandle: FileHandle, delimiter: Delimiter,
             readBufferSize: Int, skipFirstRow: Bool)
        {
            self.columnCount = columnCount
            self.delimiter = delimiter

            // Allocate continuous memory for field pointers
            storage = UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>.allocate(capacity: columnCount)
            for i in 0 ..< columnCount {
                storage[i] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
            }

            // Initialize chunk reader
            chunkReader = FileChunkReader(fileHandle: fileHandle, readBufferSize: readBufferSize)

            // Skip the header row if requested
            if skipFirstRow {
                skipRow()
                currentRowNumber = 2
            }
        }

        /// Skips a single row in the CSV data
        private mutating func skipRow() {
            // State tracking for quotes
            var inQuote = false

            while true {
                chunkReader.loadNextChunkIfNeeded()

                if chunkReader.isFinished { return }

                guard let bytes = chunkReader.currentBytes else { return }

                // Process the current chunk to find the end of row
                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    // Handle quote character
                    if byte == delimiter.value {
                        if !inQuote && chunkReader.currentPosition == fieldStartPosition {
                            // Opening quote at start of field
                            inQuote = true
                            chunkReader.advancePosition()
                            continue
                        } else if inQuote {
                            // Check for escaped quote
                            if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize &&
                                bytes[chunkReader.currentPosition + 1] == delimiter.value
                            {
                                chunkReader.advancePosition(by: 2)
                                continue
                            } else {
                                // Closing quote
                                inQuote = false
                                chunkReader.advancePosition()
                                continue
                            }
                        } else {
                            // Normal character in field
                            chunkReader.advancePosition()
                            continue
                        }
                    } else if !inQuote && byte == delimiter.row {
                        // End of row found
                        chunkReader.advancePosition()

                        // Handle CR+LF sequence
                        if byte == UInt8(ascii: "\r") &&
                            chunkReader.currentPosition < chunkReader.currentReadBufferSize &&
                            bytes[chunkReader.currentPosition] == UInt8(ascii: "\n")
                        {
                            chunkReader.advancePosition()
                        }

                        fieldStartPosition = chunkReader.currentPosition
                        return
                    } else {
                        // Normal character
                        chunkReader.advancePosition()
                    }
                }

                // If we get here, we need to load more data
                fieldStartPosition = 0
            }
        }

        mutating func parseNextRow() -> CSVIteratorResult? {
            // Clear any previous parsing error before starting a new row
            parsingError = nil

            var currentFieldIndex = 0
            fieldStartPosition = chunkReader.currentPosition

            // State tracking for quotes
            var inQuote = false

            // Parse until we find a complete row
            while true {
                chunkReader.loadNextChunkIfNeeded()

                if chunkReader.isFinished {
                    // Process any final field at EOF if needed
                    if chunkReader.currentPosition > fieldStartPosition && chunkReader.currentBytes != nil {
                        // Since we have a fixed allocation, we know when we're exceeding capacity
                        if currentFieldIndex < columnCount {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: chunkReader.currentBytes!
                            )
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            // Only set error if not already set
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }
                    }

                    return currentFieldIndex > 0 ?
                        CSVIteratorResult(directStorage: UnsafeBufferPointer(storage),
                                          count: currentFieldIndex,
                                          parsingError: parsingError) : nil
                }

                guard let bytes = chunkReader.currentBytes else {
                    return nil
                }

                // Process the current chunk to find field boundaries
                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    // Handle quote character
                    if byte == delimiter.value {
                        // Only treat as opening quote if at the start of a field and not in a quoted context
                        if !inQuote && chunkReader.currentPosition == fieldStartPosition {
                            // Opening quote at start of field
                            inQuote = true
                            // We want to keep the quote in the field to properly detect quoted fields later
                            chunkReader.advancePosition()
                            continue
                        } else if inQuote {
                            // Check for escaped quote (double quote) inside quoted field
                            if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize &&
                                bytes[chunkReader.currentPosition + 1] == delimiter.value
                            {
                                // Skip one of the quotes, keeping the other in the field
                                chunkReader.advancePosition(by: 2)
                                continue
                            } else {
                                // Closing quote - need to find the field/row delimiter
                                inQuote = false
                                chunkReader.advancePosition()
                                continue
                            }
                        } else {
                            // Handle quote that's not at the start of the field as a normal character
                            chunkReader.advancePosition()
                            continue
                        }
                    } else if !inQuote && byte == delimiter.field {
                        // End of field - simplified logic that assumes storage has adequate capacity
                        if currentFieldIndex < columnCount {
                            // Store field directly without extra checks
                            if chunkReader.currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: chunkReader.currentPosition,
                                    in: bytes
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            // Only set error if not already set
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }

                        // Update for next field
                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition
                    } else if !inQuote && byte == delimiter.row {
                        // End of row - simplified logic that assumes storage has adequate capacity
                        if currentFieldIndex < columnCount {
                            // Store field directly without extra checks
                            if chunkReader.currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: chunkReader.currentPosition,
                                    in: bytes
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            // Only set error if not already set
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }

                        // Move past the row delimiter and handle CR+LF
                        chunkReader.advancePosition()
                        if byte == UInt8(ascii: "\r") && chunkReader.currentPosition < chunkReader.currentReadBufferSize &&
                            bytes[chunkReader.currentPosition] == UInt8(ascii: "\n")
                        {
                            chunkReader.advancePosition()
                        }

                        fieldStartPosition = chunkReader.currentPosition

                        // Create result using the optimized direct storage accessor
                        let result = CSVIteratorResult(
                            directStorage: UnsafeBufferPointer(storage),
                            count: currentFieldIndex,
                            parsingError: parsingError
                        )

                        currentRowNumber += 1
                        return result
                    } else {
                        // Normal character - just advance
                        chunkReader.advancePosition()
                    }
                }
            }
        }

        /// Release allocated resources
        mutating func cleanup() {
            storage.deallocate()
            chunkReader.cleanup()
        }
    }
}
