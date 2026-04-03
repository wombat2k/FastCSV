import Foundation

/// Configuration options for CSV writing.
public struct CSVWriterConfig {
    /// Delimiters used in the CSV output (field, row, quote).
    public let delimiter: Delimiter

    /// Date formatter for Date values. Defaults to "yyyy-MM-dd" matching the reader.
    public let dateFormatter: DateFormatter

    /// Initialize a new CSV writer configuration.
    /// - Parameters:
    ///   - delimiter: CSV delimiters (default: CSV format with comma, newline, double-quote)
    ///   - dateFormatter: Formatter for Date values (default: "yyyy-MM-dd")
    public init(
        delimiter: Delimiter? = nil,
        dateFormatter: DateFormatter? = nil
    ) {
        self.delimiter = delimiter ?? CSVFormat.csv.delimiter
        self.dateFormatter = dateFormatter ?? CSVValue.defaultDateFormatter
    }
}
