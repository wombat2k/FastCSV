import Foundation

extension FastCSV {
    /// Defines the type of parser to use for CSV parsing
    enum ParserType {
        /// Used when column count is unknown.
        case dynamic
        /// Used when the column count is known
        case fixed(capacity: Int)
        /// Fixed allocation without quotes parsing
        case fixedNoQuotes(capacity: Int)
    }
}
