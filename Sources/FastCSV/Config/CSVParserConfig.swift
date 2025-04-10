import Foundation

/// Configuration options for CSV parsing
public struct CSVParserConfig {
    /// Delimiters used in the CSV file
    public let delimiter: Delimiter

    /// Size of the buffer used when reading from disk (in bytes)
    public let readBufferSize: Int

    /// Whether to assume that the CSV file does not contain any quoted fields
    public let assumeNoQuotes: Bool

    /// Initialize a new CSV parser configuration
    /// - Parameters:
    ///   - delimiter: CSV delimiters (field, row, quote) (default: CSV format with comma, newline, double-quote)
    ///   - readBufferSize: Size of the buffer used when reading from disk (in bytes, default: 256 KB)
    public init(
        delimiter: Delimiter? = nil,
        readBufferSize: Int = 256 * 1024,
        assumeNoQuotes: Bool = false
    ) {
        self.delimiter = delimiter ?? CSVFormat.csv.delimiter
        self.readBufferSize = readBufferSize
        self.assumeNoQuotes = assumeNoQuotes
    }
}
