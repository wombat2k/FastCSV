import Foundation

public enum CSVError: Error {
    /// Error indicating that the CSV file is empty or that there is a problem reading the file.
    /// This is a fatal error and is not recoverable.
    case invalidFile(message: String)
    /// Error indicating that the CSV file is not in a valid format.
    /// This is a fatal error and is not recoverable.
    case invalidCSV(message: String)
    /// Error indicating that an invalid the original textual representation of a value cannot be converted to the desired type.
    case invalidValueConversion(message: String)
    /// Error indicating that the row contains non-fatal errors.
    case rowError(row: Int, message: String)
}
