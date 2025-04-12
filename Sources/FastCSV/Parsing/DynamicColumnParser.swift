import Foundation

extension FastCSV {
    /// Parser for CSV data with a variable number of columns
    struct DynamicColumnParser: CSVParser {
        /// Collection of field pointers
        private var fieldPointers: [UnsafeBufferPointer<UInt8>]
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

        init(fileHandle: FileHandle, delimiter: Delimiter, readBufferSize: Int,
             skipFirstRow: Bool, initialCapacity: Int = 0)
        {
            self.delimiter = delimiter

            // Initialize field pointers array
            if initialCapacity > 0 {
                fieldPointers = []
                fieldPointers.reserveCapacity(initialCapacity)
            } else {
                fieldPointers = []
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

            // Clear the array but keep capacity
            fieldPointers.removeAll(keepingCapacity: true)

            fieldStartPosition = chunkReader.currentPosition

            // State tracking for quotes
            var inQuote = false

            // Parse until we find a complete row
            while true {
                chunkReader.loadNextChunkIfNeeded()

                if chunkReader.isFinished {
                    // Process any final field at EOF if needed
                    if chunkReader.currentPosition > fieldStartPosition && chunkReader.currentBytes != nil {
                        let fieldPointer = createFieldPointer(
                            from: fieldStartPosition,
                            to: chunkReader.currentPosition,
                            in: chunkReader.currentBytes!
                        )
                        fieldPointers.append(fieldPointer)
                    }

                    return fieldPointers.isEmpty ? nil : CSVIteratorResult(fieldPointers: fieldPointers, parsingError: parsingError)
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
                            if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize && bytes[chunkReader.currentPosition + 1] == delimiter.value {
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
                        // End of field - create a pointer to the current field
                        if chunkReader.currentPosition > fieldStartPosition {
                            fieldPointers.append(createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: bytes
                            ))
                        } else {
                            // Empty field
                            fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
                        }

                        // Update for next field
                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition
                    } else if !inQuote && byte == delimiter.row {
                        // End of row - finalize the current field
                        if chunkReader.currentPosition > fieldStartPosition {
                            fieldPointers.append(createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: bytes
                            ))
                        } else {
                            // Empty field at end of row
                            fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
                        }

                        // Move past the row delimiter
                        chunkReader.advancePosition()

                        // Handle CR+LF sequence
                        if byte == UInt8(ascii: "\r") && chunkReader.currentPosition < chunkReader.currentReadBufferSize &&
                            bytes[chunkReader.currentPosition] == UInt8(ascii: "\n")
                        {
                            chunkReader.advancePosition()
                        }

                        fieldStartPosition = chunkReader.currentPosition

                        // Create result using dynamic fieldPointers array
                        let result = CSVIteratorResult(fieldPointers: fieldPointers, parsingError: parsingError)

                        currentRowNumber += 1
                        return result
                    } else {
                        // Normal character - just advance
                        chunkReader.advancePosition()
                    }
                }
            }
        }

        /// Release any resources used by this parser
        mutating func cleanup() {
            // Clean up the field pointers and chunk reader
            fieldPointers = []
            chunkReader.cleanup()
        }
    }
}
