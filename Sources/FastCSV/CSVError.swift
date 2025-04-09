import Foundation

public enum CSVError: Error {
    case invalidFile(message: String)
    case invalidCSV(message: String)
    case invalidHeaders(message: String)
    case invalidValueConversion(message: String)
    case rowError(row: Int, message: String)
}
