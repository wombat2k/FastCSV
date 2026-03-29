import Foundation

extension FastCSV {
    /// Protocol defining the requirements for a CSV parser implementation
    protocol CSVParser {
        /// Parses the next row from the CSV data
        /// Returns: A CSVIteratorResult representing the parsed row, or nil if end of data
        mutating func parseNextRow() -> CSVIteratorResult?

        /// Releases any resources used by this parser
        mutating func cleanup()
    }
}

// Extension with common helper methods for CSV parsers
internal extension FastCSV.CSVParser {
    /// Creates a field pointer from byte buffer
    func createFieldPointer(from startPosition: Int, to endPosition: Int,
                            in bytes: UnsafePointer<UInt8>) -> UnsafeBufferPointer<UInt8>
    {
        let length = endPosition - startPosition
        return UnsafeBufferPointer(
            start: bytes.advanced(by: startPosition),
            count: length
        )
    }

    /// Adjusts a field end position to strip a trailing \r when the row delimiter is \n
    /// in a \r\n (CRLF) sequence. Returns the adjusted end position.
    func adjustFieldEndForCRLF(byte: UInt8, fieldEnd: Int, fieldStart: Int,
                               bytes: UnsafePointer<UInt8>) -> Int
    {
        if byte == UInt8(ascii: "\n") && fieldEnd > fieldStart &&
            bytes[fieldEnd - 1] == UInt8(ascii: "\r")
        {
            return fieldEnd - 1
        }
        return fieldEnd
    }
}

internal extension FastCSV {
    /// Shared implementation for skipping a row in quote-aware parsers.
    /// Used by FixedColumnParser and DynamicColumnParser.
    static func skipQuotedRow(
        chunkReader: inout ByteChunkReader,
        delimiter: Delimiter,
        fieldStartPosition: inout Int
    ) {
        var inQuote = false

        while true {
            chunkReader.loadNextChunkIfNeeded()

            if chunkReader.isFinished { return }

            guard let bytes = chunkReader.currentBytes else { return }

            while chunkReader.currentPosition < chunkReader.currentReadBufferSize {
                let byte = bytes[chunkReader.currentPosition]

                if byte == delimiter.quote {
                    if !inQuote && chunkReader.currentPosition == fieldStartPosition {
                        inQuote = true
                        chunkReader.advancePosition()
                        continue
                    } else if inQuote {
                        if chunkReader.currentPosition + 1 < chunkReader.currentReadBufferSize &&
                            bytes[chunkReader.currentPosition + 1] == delimiter.quote
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
                } else if !inQuote && byte == delimiter.row {
                    chunkReader.advancePosition()

                    if byte == UInt8(ascii: "\r") &&
                        chunkReader.currentPosition < chunkReader.currentReadBufferSize &&
                        bytes[chunkReader.currentPosition] == UInt8(ascii: "\n")
                    {
                        chunkReader.advancePosition()
                    }

                    fieldStartPosition = chunkReader.currentPosition
                    return
                } else {
                    chunkReader.advancePosition()
                }
            }

            fieldStartPosition = 0
        }
    }
}
