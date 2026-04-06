// swiftlint:disable cyclomatic_complexity function_body_length type_body_length
import Foundation

extension FastCSV {
    /// Result of reading the first row during parser initialization.
    struct FirstRowResult {
        /// First row data, as copied byte arrays. Nil if the file was empty.
        let fields: [[UInt8]]?
        /// Parsing error from the first row, if any.
        let error: CSVError?
    }

    /// CSV parser that reads the first row during init to discover column count,
    /// then uses pre-allocated fixed storage for all subsequent rows.
    struct CSVParser {
        /// File chunk reader
        private var chunkReader: ByteChunkReader
        /// CSV delimiter configuration
        private let delimiter: Delimiter
        /// Whether to skip quote handling entirely (fast path)
        private let noQuotes: Bool
        /// Current row number being processed
        private var currentRowNumber: Int = 1
        /// Current parsing error, if any
        private var parsingError: CSVError?
        /// Current field start position
        private var fieldStartPosition: Int = 0

        /// Pre-allocated storage for field pointers
        private var storage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>
        /// Known column count from row 1
        private let columnCount: Int
        /// Tracks cleanup state for the pre-allocated storage
        private let cleanupState: CleanupTracker

        /// Reads the first row to discover column count, returns the parser and the first row data.
        static func create(reader: ByteStreamReader, delimiter: Delimiter, readBufferSize: Int,
                           noQuotes: Bool = false) -> (parser: CSVParser, firstRow: FirstRowResult)
        {
            let chunkReader = ByteChunkReader(reader: reader, readBufferSize: readBufferSize)

            // Parse row 1 to discover column count
            var fields: [[UInt8]] = []
            var error: CSVError? = nil
            var inQuote = false
            var fieldStart = 0

            rowScan: while true {
                chunkReader.loadNextChunkIfNeeded()

                if fieldStart > chunkReader.currentPosition {
                    fieldStart = chunkReader.currentPosition
                }

                if chunkReader.isFinished {
                    if inQuote {
                        error = .rowError(row: 1, message: "Row 1 has an unclosed quote.")
                    }

                    if chunkReader.currentPosition > fieldStart, let bytes = chunkReader.currentBytes {
                        let length = chunkReader.currentPosition - fieldStart
                        fields.append(Array(UnsafeBufferPointer(start: bytes.advanced(by: fieldStart), count: length)))
                    }

                    break rowScan
                }

                guard let bytes = chunkReader.currentBytes else {
                    break rowScan
                }

                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    if byte == delimiter.quoteByte {
                        if !inQuote, chunkReader.currentPosition == fieldStart {
                            inQuote = true
                            chunkReader.advancePosition()
                            continue
                        } else if inQuote {
                            if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize,
                               bytes[chunkReader.currentPosition + 1] == delimiter.quoteByte
                            {
                                chunkReader.advancePosition(by: 2)
                                continue
                            } else {
                                inQuote = false
                                chunkReader.advancePosition()
                                continue
                            }
                        } else {
                            chunkReader.advancePosition()
                            continue
                        }
                    } else if !inQuote, byte == delimiter.fieldByte {
                        if chunkReader.currentPosition > fieldStart {
                            let length = chunkReader.currentPosition - fieldStart
                            fields.append(Array(UnsafeBufferPointer(start: bytes.advanced(by: fieldStart), count: length)))
                        } else {
                            fields.append([])
                        }

                        chunkReader.advancePosition()
                        fieldStart = chunkReader.currentPosition
                    } else if !inQuote, byte == delimiter.rowByte {
                        var fieldEnd = chunkReader.currentPosition
                        if byte == UInt8(ascii: "\n"), fieldEnd > fieldStart,
                           bytes[fieldEnd - 1] == UInt8(ascii: "\r")
                        {
                            fieldEnd -= 1
                        }

                        if fieldEnd > fieldStart {
                            let length = fieldEnd - fieldStart
                            fields.append(Array(UnsafeBufferPointer(start: bytes.advanced(by: fieldStart), count: length)))
                        } else {
                            fields.append([])
                        }

                        chunkReader.advancePosition()
                        break rowScan
                    } else {
                        chunkReader.advancePosition()
                    }
                }

                chunkReader.extendIntoNextChunk(from: fieldStart)
                fieldStart = 0
            }

            chunkReader.releaseRetainedBuffers()

            let fieldStartPosition = chunkReader.currentPosition
            let colCount = fields.isEmpty ? 0 : fields.count

            let storage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>
            if colCount > 0 {
                storage = .allocate(capacity: colCount)
                for index in 0 ..< colCount {
                    storage[index] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                }
            } else {
                storage = .allocate(capacity: 0)
            }

            let parser = CSVParser(
                chunkReader: chunkReader,
                delimiter: delimiter,
                noQuotes: noQuotes,
                fieldStartPosition: fieldStartPosition,
                storage: storage,
                columnCount: colCount,
            )

            let firstRow = FirstRowResult(
                fields: fields.isEmpty ? nil : fields,
                error: error,
            )

            return (parser, firstRow)
        }

        private init(chunkReader: ByteChunkReader, delimiter: Delimiter, noQuotes: Bool,
                     fieldStartPosition: Int, storage: UnsafeMutableBufferPointer<UnsafeBufferPointer<UInt8>>,
                     columnCount: Int)
        {
            self.chunkReader = chunkReader
            self.delimiter = delimiter
            self.noQuotes = noQuotes
            cleanupState = CleanupTracker()
            self.fieldStartPosition = fieldStartPosition
            self.storage = storage
            self.columnCount = columnCount
            currentRowNumber = 2
        }

        mutating func parseNextRow() -> CSVIteratorResult? {
            chunkReader.releaseRetainedBuffers()

            if chunkReader.isFinished {
                cleanup()
                return nil
            }

            parsingError = nil

            if noQuotes {
                return parseRowNoQuotes()
            } else {
                return parseRowWithQuotes()
            }
        }

        // MARK: - Quote-aware inner loop

        @inline(__always)
        private mutating func parseRowWithQuotes() -> CSVIteratorResult? {
            var inQuote = false
            var currentFieldIndex = 0

            while true {
                chunkReader.loadNextChunkIfNeeded()

                if fieldStartPosition > chunkReader.currentPosition {
                    fieldStartPosition = chunkReader.currentPosition
                }

                if chunkReader.isFinished {
                    if inQuote && parsingError == nil {
                        parsingError = .rowError(
                            row: currentRowNumber,
                            message: "Row \(currentRowNumber) has an unclosed quote.",
                        )
                    }

                    if chunkReader.currentPosition > fieldStartPosition && chunkReader.currentBytes != nil {
                        if currentFieldIndex < columnCount {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: chunkReader.currentBytes!,
                            )
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
                            )
                        }
                    }

                    return currentFieldIndex > 0 ?
                        CSVIteratorResult(directStorage: UnsafeBufferPointer(storage),
                                          count: currentFieldIndex,
                                          parsingError: parsingError) : nil
                }

                guard let bytes = chunkReader.currentBytes else {
                    cleanup()
                    return nil
                }

                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    if byte == delimiter.quoteByte {
                        if !inQuote, chunkReader.currentPosition == fieldStartPosition {
                            inQuote = true
                            chunkReader.advancePosition()
                            continue
                        } else if inQuote {
                            if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize,
                               bytes[chunkReader.currentPosition + 1] == delimiter.quoteByte
                            {
                                chunkReader.advancePosition(by: 2)
                                continue
                            } else {
                                inQuote = false
                                chunkReader.advancePosition()
                                continue
                            }
                        } else {
                            chunkReader.advancePosition()
                            continue
                        }
                    } else if !inQuote, byte == delimiter.fieldByte {
                        if currentFieldIndex < columnCount {
                            if chunkReader.currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: chunkReader.currentPosition,
                                    in: bytes,
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
                            )
                        }

                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition
                    } else if !inQuote, byte == delimiter.rowByte {
                        let fieldEnd = adjustFieldEndForCRLF(
                            byte: byte, fieldEnd: chunkReader.currentPosition,
                            fieldStart: fieldStartPosition, bytes: bytes,
                        )

                        if currentFieldIndex < columnCount {
                            if fieldEnd > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: fieldEnd,
                                    in: bytes,
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
                            )
                        }

                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition

                        let result = CSVIteratorResult(
                            directStorage: UnsafeBufferPointer(storage),
                            count: currentFieldIndex,
                            parsingError: parsingError,
                        )

                        currentRowNumber += 1
                        return result
                    } else {
                        chunkReader.advancePosition()
                    }
                }

                chunkReader.extendIntoNextChunk(from: fieldStartPosition)
                fieldStartPosition = 0
            }
        }

        // MARK: - No-quotes inner loop

        @inline(__always)
        private mutating func parseRowNoQuotes() -> CSVIteratorResult? {
            var currentFieldIndex = 0

            while true {
                chunkReader.loadNextChunkIfNeeded()

                if fieldStartPosition > chunkReader.currentPosition {
                    fieldStartPosition = chunkReader.currentPosition
                }

                if chunkReader.isFinished {
                    if chunkReader.currentPosition > fieldStartPosition && chunkReader.currentBytes != nil {
                        if currentFieldIndex < columnCount {
                            storage[currentFieldIndex] = createFieldPointer(
                                from: fieldStartPosition,
                                to: chunkReader.currentPosition,
                                in: chunkReader.currentBytes!,
                            )
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
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

                while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                    let byte = bytes[chunkReader.currentPosition]

                    if byte == delimiter.fieldByte {
                        if currentFieldIndex < columnCount {
                            if chunkReader.currentPosition > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: chunkReader.currentPosition,
                                    in: bytes,
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
                            )
                        }

                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition
                    } else if byte == delimiter.rowByte {
                        let fieldEnd = adjustFieldEndForCRLF(
                            byte: byte, fieldEnd: chunkReader.currentPosition,
                            fieldStart: fieldStartPosition, bytes: bytes,
                        )

                        if currentFieldIndex < columnCount {
                            if fieldEnd > fieldStartPosition {
                                storage[currentFieldIndex] = createFieldPointer(
                                    from: fieldStartPosition,
                                    to: fieldEnd,
                                    in: bytes,
                                )
                            } else {
                                storage[currentFieldIndex] = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                            }
                            currentFieldIndex += 1
                        } else if parsingError == nil {
                            parsingError = .rowError(
                                row: currentRowNumber,
                                message: "Row \(currentRowNumber) has more columns than expected: got \(currentFieldIndex + 1), expected \(columnCount).",
                            )
                        }

                        chunkReader.advancePosition()
                        fieldStartPosition = chunkReader.currentPosition

                        let result = CSVIteratorResult(
                            directStorage: UnsafeBufferPointer(storage),
                            count: currentFieldIndex,
                            parsingError: parsingError,
                        )

                        currentRowNumber += 1
                        return result
                    } else {
                        chunkReader.advancePosition()
                    }
                }

                chunkReader.extendIntoNextChunk(from: fieldStartPosition)
                fieldStartPosition = 0
            }
        }

        // MARK: - Cleanup

        mutating func cleanup() {
            if !cleanupState.hasBeenCleaned {
                storage.deallocate()
                chunkReader.cleanup()
                cleanupState.hasBeenCleaned = true
            }
        }

        // MARK: - Helpers

        private func createFieldPointer(from startPosition: Int, to endPosition: Int,
                                        in bytes: UnsafePointer<UInt8>) -> UnsafeBufferPointer<UInt8>
        {
            let length = endPosition - startPosition
            return UnsafeBufferPointer(
                start: bytes.advanced(by: startPosition),
                count: length,
            )
        }

        private func adjustFieldEndForCRLF(byte: UInt8, fieldEnd: Int, fieldStart: Int,
                                           bytes: UnsafePointer<UInt8>) -> Int
        {
            if byte == UInt8(ascii: "\n"), fieldEnd > fieldStart,
               bytes[fieldEnd - 1] == UInt8(ascii: "\r")
            {
                return fieldEnd - 1
            }
            return fieldEnd
        }
    }
}
