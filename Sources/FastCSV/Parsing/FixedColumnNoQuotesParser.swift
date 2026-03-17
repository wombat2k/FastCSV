import Foundation

extension FastCSV {
    /// Parser for CSV data with a fixed number of columns, optimized for data without quotes
    struct FixedColumnNoQuotesParser: CSVParser {
        /// Number of columns to parse
        private let columnCount: Int
        /// Storage for parsed fields
        private let storage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>
        /// File chunk reader
        private var chunkReader: ByteChunkReader
        /// CSV delimiter configuration
        private let delimiter: Delimiter
        /// Current row number being processed
        private var currentRowNumber: Int = 1
        /// Current parsing error, if any
        private var parsingError: CSVError?
        /// Current field start position
        private var fieldStartPosition: Int = 0

        // A reference type to track cleanup state
        private let cleanupState: CleanupTracker

        init(columnCount: Int, reader: ByteStreamReader, delimiter: Delimiter,
             readBufferSize: Int, skipFirstRow: Bool)
        {
            self.columnCount = columnCount
            self.delimiter = delimiter
            cleanupState = CleanupTracker()

            // Allocate continuous memory for field pointers
            storage = UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>.allocate(capacity: columnCount)
            for i in 0 ..< columnCount {
                storage[i] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
            }

            // Initialize chunk reader
            chunkReader = ByteChunkReader(reader: reader, readBufferSize: readBufferSize)

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
            // Release any buffers retained from a previous row's chunk extensions
            chunkReader.releaseRetainedBuffers()

            // If we already reached EOF on a previous call, clean up and return nil
            if chunkReader.isFinished {
                cleanup()
                return nil
            }

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

                    // Don't cleanup here — the returned result's field pointers
                    // reference storage and chunk buffers. Cleanup happens on the
                    // next call to parseNextRow (which returns nil) or via explicit cleanup.
                    return currentFieldIndex > 0 ?
                        CSVIteratorResult(directStorage: UnsafeBufferPointer(storage),
                                          count: currentFieldIndex,
                                          parsingError: parsingError) : nil
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

                        let result = CSVIteratorResult(
                            directStorage: UnsafeBufferPointer(storage),
                            count: currentFieldIndex,
                            parsingError: parsingError
                        )

                        currentRowNumber += 1
                        return result
                    } else if byte == UInt8(ascii: "\"") {
                        // Create error result first with a completely separate buffer
                        let emptyFields: [UnsafeBufferPointer<UInt8>] = []
                        let errorResult = CSVIteratorResult(
                            fieldPointers: emptyFields,
                            parsingError: .invalidCSV(message: "File contains quotes but was parsed in no-quotes mode")
                        )

                        // Then clean up resources
                        cleanup()

                        return errorResult
                    } else {
                        // Normal character - just advance
                        chunkReader.advancePosition()
                    }
                }

                // Inner loop exhausted the chunk without completing a field.
                // Retain the old buffer (field pointers reference it) and load new data.
                chunkReader.extendIntoNextChunk(from: fieldStartPosition)
                fieldStartPosition = 0
            }
        }

        /// Release allocated resources - made idempotent
        mutating func cleanup() {
            if !cleanupState.hasBeenCleaned {
                storage.deallocate()
                chunkReader.cleanup()
                cleanupState.hasBeenCleaned = true
            }
        }
    }
}
