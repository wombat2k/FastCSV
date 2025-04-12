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
extension FastCSV.CSVParser {
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
}
