#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

public enum CSVError: Error {
    /// Error indicating that the delimiter character is invalid (not an ASCII character).
    case invalidDelimiter(message: String)
    /// Error indicating that the CSV file is empty or that there is a problem reading the file.
    /// This is a fatal error and is not recoverable.
    case invalidFile(message: String)
    /// Error indicating that the CSV file is not in a valid format.
    /// This is a fatal error and is not recoverable.
    case invalidCSV(message: String)
    /// Error indicating that the original textual representation of a value cannot be converted to the desired type.
    case invalidValueConversion(message: String)
    /// Error indicating that the row contains non-fatal errors.
    case rowError(row: Int, message: String)
    /// Error during CSV writing (file creation failure, state violations, encoding issues).
    case writeError(message: String)
}

extension CSVError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .invalidDelimiter(message),
             let .invalidFile(message),
             let .invalidCSV(message),
             let .invalidValueConversion(message),
             let .writeError(message):
            return message
        case let .rowError(row, message):
            return "Row \(row): \(message)"
        }
    }
}
