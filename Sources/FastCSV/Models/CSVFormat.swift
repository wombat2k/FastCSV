#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

/// Predefined formats for common CSV-like files
public enum CSVFormat {
    /// Standard CSV format: comma-separated values with double quotes
    case csv

    /// Tab-separated values
    case tsv

    /// Semicolon-separated values (common in European locales)
    case semiColonSeparated

    /// Custom format with specific delimiters
    case custom(field: UInt8, row: UInt8, quote: UInt8)

    /// Get the delimiter configuration for this format
    public var delimiter: Delimiter {
        switch self {
        case .csv:
            Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: ","), quote: UInt8(ascii: "\""))
        case .tsv:
            Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: "\t"), quote: UInt8(ascii: "\""))
        case .semiColonSeparated:
            Delimiter(row: UInt8(ascii: "\n"), field: UInt8(ascii: ";"), quote: UInt8(ascii: "\""))
        case let .custom(field, row, quote):
            Delimiter(row: row, field: field, quote: quote)
        }
    }
}
