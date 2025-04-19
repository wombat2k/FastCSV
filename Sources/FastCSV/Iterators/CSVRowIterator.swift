import Foundation

extension FastCSV {
    /// Zero-copy iterator for CSV rows, returning raw field pointers to the underlying buffer
    struct CSVRowIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVIteratorResult

        // Parser implementation to use for row parsing
        private var parser: CSVParser

        /// Initialize a CSVIterator for parsing a CSV file with a FileHandle
        /// - Parameters:
        ///   - fileHandle: FileHandle to read CSV data from
        ///   - skipFirstRow: Whether to skip the first row during iteration (default: true)
        ///   - config: Configuration options for CSV parsing
        init(fileHandle: FileHandle, skipFirstRow: Bool = true, columnCount: Int = 0, config: CSVParserConfig) {
            // Create the appropriate parser based on configuration
            if columnCount > 0 {
                if !config.assumeNoQuotes {
                    parser = FixedColumnParser(
                        columnCount: columnCount,
                        fileHandle: fileHandle,
                        delimiter: config.delimiter,
                        readBufferSize: config.readBufferSize,
                        skipFirstRow: skipFirstRow
                    )
                } else {
                    parser = FixedColumnNoQuotesParser(
                        columnCount: columnCount,
                        fileHandle: fileHandle,
                        delimiter: config.delimiter,
                        readBufferSize: config.readBufferSize,
                        skipFirstRow: skipFirstRow
                    )
                }
            } else {
                // Use dynamic column parser for unknown column count
                parser = DynamicColumnParser(
                    fileHandle: fileHandle,
                    delimiter: config.delimiter,
                    readBufferSize: config.readBufferSize,
                    skipFirstRow: skipFirstRow
                )
            }
        }

        /// Get the next row of CSV data
        /// - Returns: A CSVIteratorResult containing the row data, or nil if no more rows are available
        public mutating func next() -> CSVIteratorResult? {
            // Simply delegate to parser - all state is maintained within the parser
            return parser.parseNextRow()
        }

        /// Cleans up the parser and releases any resources it holds.
        /// - Note: This method only needs to be called if the iterator is not used in a `forEach` loop or if the iterator is not iterated until the end of the file.
        public mutating func cleanup() {
            // Clean up the parser - each implementation handles its own specific cleanup
            parser.cleanup()
        }

        /// Iterates through all rows in the CSV file and applies the given closure to each row of raw buffer pointers.
        /// - Parameter body: The closure to apply to each row, where the row is represented as a CSVIteratorResult.
        /// - Note: This method will automatically clean up resources after processing all rows.
        mutating func forEach(_ body: (CSVIteratorResult) -> Void) {
            defer {
                cleanup()
            }

            // Process each row and call the provided closure
            while let result = next() {
                body(result)
            }
        }
    }
}
