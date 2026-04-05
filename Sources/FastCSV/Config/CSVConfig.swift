import Foundation

/// Configuration options for CSV parsing and writing.
public struct CSVConfig {
    /// Delimiters used in the CSV file (field, row, quote).
    public let delimiter: Delimiter

    /// Size of the buffer used when reading from disk (in bytes). Ignored by the writer.
    /// A larger buffer size can improve performance when reading large files, but will use more
    /// memory. Defaults to 256 KB, which is a good balance for most use cases.
    public let readBufferSize: Int

    /// Whether to assume that the CSV file does not contain any quoted fields. Ignored by the writer.
    /// The parser will report an error if it encounters a quote character when this is true.
    /// Setting this to true can improve performance when parsing large files that do not contain
    /// any quoted fields, but it should only be used if you are certain that the file does not
    /// contain any quotes.
    public let assumeNoQuotes: Bool

    /// Date formatter for Date values. Defaults to "yyyy-MM-dd". Ignored by the reader.
    public let dateFormatter: DateFormatter

    public init(
        delimiter: Delimiter? = nil,
        readBufferSize: Int = 256 * 1024,
        assumeNoQuotes: Bool = false,
        dateFormatter: DateFormatter? = nil
    ) {
        self.delimiter = delimiter ?? CSVFormat.csv.delimiter
        self.readBufferSize = readBufferSize
        self.assumeNoQuotes = assumeNoQuotes
        self.dateFormatter = dateFormatter ?? CSVValue.defaultDateFormatter
    }
}

/// Backward compatibility aliases.
public typealias CSVParserConfig = CSVConfig
public typealias CSVWriterConfig = CSVConfig
