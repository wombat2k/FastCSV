import Foundation

/// Predefined formats for common CSV-like files
public enum CSVFormat {
    /// Standard CSV format: comma-separated values with double quotes
    case csv

    /// Tab-separated values
    case tsv

    /// Semicolon-separated values (common in European locales)
    case semiColonSeparated

    /// Custom format with specific delimiters
    case custom(field: UInt8, row: UInt8, value: UInt8)

    /// Get the delimiter configuration for this format
    var delimiter: Delimiter {
        switch self {
        case .csv:
            return Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: ","), value: UInt8(ascii: "\""))
        case .tsv:
            return Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: "\t"), value: UInt8(ascii: "\""))
        case .semiColonSeparated:
            return Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: ";"), value: UInt8(ascii: "\""))
        case let .custom(field, row, value):
            return Delimiter(row: row, field: field, value: value)
        }
    }
}
