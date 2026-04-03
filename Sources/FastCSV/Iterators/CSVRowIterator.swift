import Foundation

extension FastCSV {
    /// Zero-copy iterator for CSV rows, returning raw field pointers to the underlying buffer
    struct CSVRowIterator: IteratorProtocol, Sequence {
        public typealias Element = CSVIteratorResult

        private var parser: CSVParser

        /// The first row parsed during init, as copied byte arrays. Nil if the file was empty.
        let firstRow: FirstRowResult

        init(reader: ByteStreamReader, config: CSVParserConfig) {
            let result = CSVParser.create(
                reader: reader,
                delimiter: config.delimiter,
                readBufferSize: config.readBufferSize,
                noQuotes: config.assumeNoQuotes
            )
            self.parser = result.parser
            self.firstRow = result.firstRow
        }

        /// Get the next row of CSV data (starts at row 2; row 1 is available via `firstRow`)
        public mutating func next() -> CSVIteratorResult? {
            return parser.parseNextRow()
        }

        /// Cleans up the parser and releases any resources it holds.
        public mutating func cleanup() {
            parser.cleanup()
        }

        /// Iterates through all rows and applies the given closure to each row.
        mutating func forEach(_ body: (CSVIteratorResult) -> Void) {
            defer { cleanup() }

            while let result = next() {
                body(result)
            }
        }
    }
}
