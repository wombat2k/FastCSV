import Foundation

extension FastCSV {
    /// Parser for CSV data with a fixed number of columns, optimized for data without quotes
    struct FixedColumnNoQuotesParser: CSVParser {
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

        /// Skips a single row in the CSV data - optimized version that doesn't handle quotes
        private mutating func skipRow() {
            while true {
                chunkReader.loadNextChunkIfNeeded()

                if chunkReader.isFinished { return }

                guard let bytes = chunkReader.currentBytes else { return }

                // Process the current chunk to find the end of row
                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    // Check for row delimiter directly
                    if byte == delimiter.row {
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
                        // Any other character - just advance
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

            // Parse until we find a complete row
            while true {
                chunkReader.loadNextChunkIfNeeded()

                if chunkReader.isFinished {
                    // Process any final field at EOF if needed
                    if chunkReader.currentPosition > fieldStartPosition && chunkReader.currentBytes != nil {
                        if currentFieldIndex < columnCount {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: chunkReader.currentBytes!
                            )
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }
                    }

                    return currentFieldIndex > 0 ?
                        CSVIteratorResult(directStorage: UnsafeBufferPointer(storage), count: currentFieldIndex, parsingError: parsingError) : nil
                }

                guard let bytes = chunkReader.currentBytes else {
                    return nil
                }

                // Process the current chunk to find field boundaries - optimized for no quotes
                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    // Handle delimiters with minimized branching
                    if byte == delimiter.field {
                        // End of field - fast path
                        if currentFieldIndex < columnCount {
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
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }

                        // Update for next field
                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition
                    } else if byte == delimiter.row {
                        // End of row - fast path
                        if currentFieldIndex < columnCount {
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
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount)."
                            )
                        }

                        // Handle CR+LF sequence
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
                    } else if byte == UInt8(ascii: "\"") {
                        // Error condition - quotes not allowed in no-quotes mode
                        parsingError = .invalidCSV(message: "File contains quotes but was parsed in no-quotes mode")

                        // Process current field before returning
                        if currentFieldIndex < columnCount && chunkReader.currentPosition > fieldStartPosition {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: bytes
                            )
                            currentFieldIndex += 1
                        }

                        // Return current fields with error
                        let result = CSVIteratorResult(
                            directStorage: UnsafeBufferPointer(storage),
                            count: currentFieldIndex,
                            parsingError: parsingError
                        )

                        // Terminate parsing
                        chunkReader.forceFinish()
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
