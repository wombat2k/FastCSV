import Foundation

extension FastCSV {
    /// Zero-copy iterator for CSV rows, returning raw field pointers to the underlying buffer
    struct CSVBaseIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVIteratorResult

        // Define allocation strategy enum to make the behavior explicit
        private enum FieldAllocationStrategy {
            case dynamic // Used when column count is unknown (initially)
            case fixed(capacity: Int) // Used once we know the column count

            var capacity: Int {
                switch self {
                case .dynamic: return 0
                case let .fixed(capacity): return capacity
                }
            }

            var isFixed: Bool {
                if case .fixed = self { return true }
                return false
            }
        }

        /// Whether parsing has finished
        private var isFinished = false

        /// Position in the current field where parsing started (for fieldPointers)
        private var fieldStartPosition = 0
        /// Collection of field pointers for nextFieldPointers method
        private var fieldPointers = [UnsafeBufferPointer<UInt8>]()
        /// Pre-allocated field pointers for reuse with fixed allocation strategy
        private var reusableFieldPointers: [UnsafeBufferPointer<UInt8>]
        /// The allocation strategy for field pointers
        private let allocationStrategy: FieldAllocationStrategy

        /// Pre-allocated contiguous storage for field pointers in fixed allocation mode
        private var fixedFieldPointersStorage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>?

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

            // Set the allocation strategy explicitly based on known column count
            if columnCount > 0 {
                allocationStrategy = .fixed(capacity: columnCount)

                // Allocate continuous memory for field pointers to avoid array operations
                let storage = UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>.allocate(capacity: columnCount)
                for i in 0 ..< columnCount {
                    storage[i] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                }
                fixedFieldPointersStorage = storage

                // Keep the normal arrays as fallbacks
                reusableFieldPointers = Array(repeating: UnsafeBufferPointer<UInt8>(start: nil, count: 0), count: columnCount)
                fieldPointers.reserveCapacity(columnCount)
            } else {
                // Use dynamic allocation when column count is unknown
                allocationStrategy = .dynamic
                reusableFieldPointers = []
                fixedFieldPointersStorage = nil
            }

            // Load initial data
            loadNextChunkIfNeeded()

            // Skip the first row if requested
            if skipFirstRow {
                _ = next()
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
            // Handle finished state
            if isFinished {
                return nil
            }

            // Dispatch to the appropriate implementation based on allocation strategy
            if case .fixed = allocationStrategy {
                return nextFieldPointersFixed()
            } else {
                return nextFieldPointersDynamic()
            }
        }

        // Enhanced cleanup for background I/O resources
        public mutating func cleanup() {
            // Close file handle if it's still open
            try? fileHandle.close()

            // Deallocate fixed storage buffer if allocated
            if let storage = fixedFieldPointersStorage {
                fixedFieldPointersStorage = nil
                storage.deallocate()
            }
        }

        // Optimized implementation for fixed column count
        private mutating func nextFieldPointersFixed() -> CSVIteratorResult? {
            guard let storage = fixedFieldPointersStorage else {
                fatalError("Fixed allocation strategy used without storage")
            }

            // Clear any previous parsing error before starting a new row
            parsingError = nil

            let maxColumns = allocationStrategy.capacity
            var currentFieldIndex = 0

            fieldStartPosition = currentPosition

            // State tracking for quotes
            var inQuote = false

            // Parse until we find a complete row
            while true {
                loadNextChunkIfNeeded()

                if isFinished {
                    // Process any final field at EOF if needed
                    if currentPosition > fieldStartPosition && currentBytes != nil {
                        // Since we have a fixed allocation, we know when we're exceeding capacity
                        if currentFieldIndex < maxColumns {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: currentPosition,
                                in: currentBytes!
                            )
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            // Only set error if not already set
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(maxColumns)."
                            )
                        }
                    }

                    return currentFieldIndex > 0 ?
                        CSVIteratorResult(directStorage: UnsafeBufferPointer(storage), count: currentFieldIndex, parsingError: parsingError) : nil
                }

                guard let bytes = currentBytes else {
                    return nil
                }

                // Process the current chunk to find field boundaries
                while currentPosition < currentReadBufferSize {
                    let byte = bytes[currentPosition]

                    // Handle quote character
                    if byte == delimiter.value {
                        // Only treat as opening quote if at the start of a field and not in a quoted context
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
                        // End of field - simplified logic that assumes storage has adequate capacity
                        if currentFieldIndex < maxColumns {
                            // Store field directly without extra checks
                            if currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: currentPosition,
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
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(maxColumns)."
                            )
                        }

                        // Update for next field
                        currentPosition += 1
                        fieldStartPosition = currentPosition
                    } else if !inQuote && byte == delimiter.row {
                        // End of row - simplified logic that assumes storage has adequate capacity
                        if currentFieldIndex < maxColumns {
                            // Store field directly without extra checks
                            if currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: currentPosition,
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
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(maxColumns)."
                            )
                        }

                        // Move past the row delimiter and handle CR+LF
                        currentPosition += 1
                        if byte == UInt8(ascii: "\r") && currentPosition < currentReadBufferSize &&
                            bytes[currentPosition] == UInt8(ascii: "\n")
                        {
                            currentPosition += 1
                        }

                        fieldStartPosition = currentPosition

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
                        currentPosition += 1
                    }
                }
            }
        }

        // Implementation for dynamic column count (only used initially)
        private mutating func nextFieldPointersDynamic() -> CSVIteratorResult? {
            // Clear any previous parsing error before starting a new row
            parsingError = nil

            // Clear the array but keep capacity
            fieldPointers.removeAll(keepingCapacity: true)

            fieldStartPosition = currentPosition

            // State tracking for quotes
            var inQuote = false

            // Parse until we find a complete row
            while true {
                loadNextChunkIfNeeded()

                if isFinished {
                    // Process any final field at EOF if needed
                    if currentPosition > fieldStartPosition && currentBytes != nil {
                        let fieldPointer = createFieldPointer(
                            from: fieldStartPosition,
                            to: currentPosition,
                            in: currentBytes!
                        )
                        fieldPointers.append(fieldPointer)
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
                        if currentPosition > fieldStartPosition {
                            fieldPointers.append(createFieldPointer(
                                from: fieldStartPosition,
                                to: currentPosition,
                                in: bytes
                            ))
                        } else {
                            // Empty field
                            fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
                        }

                        // Update for next field
                        currentPosition += 1
                        fieldStartPosition = currentPosition
                    } else if !inQuote && byte == delimiter.row {
                        // End of row - finalize the current field
                        if currentPosition > fieldStartPosition {
                            fieldPointers.append(createFieldPointer(
                                from: fieldStartPosition,
                                to: currentPosition,
                                in: bytes
                            ))
                        } else {
                            // Empty field at end of row
                            fieldPointers.append(UnsafeBufferPointer<UInt8>(start: nil, count: 0))
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

                        // Create result using dynamic fieldPointers array
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

                // Store the field pointer based on allocation strategy
                if allocationStrategy.isFixed, let storage = fixedFieldPointersStorage {
                    if let count = fixedFieldPointersStorage?.count, fieldPointers.count < count {
                        storage[fieldPointers.count] = fieldPointer
                    }
                } else {
                    fieldPointers.append(fieldPointer)
                }

                // Reset for next time
                fieldStartPosition = currentPosition
            }

            // Set parser state to finished
            isFinished = true
        }

        // Helper method to create a field pointer
        private func createFieldPointer(from startPosition: Int, to endPosition: Int, in bytes: UnsafePointer<UInt8>) -> UnsafeBufferPointer<UInt8> {
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
