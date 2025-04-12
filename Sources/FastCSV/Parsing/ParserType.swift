import Foundation

extension FastCSV {
    /// Defines the type of parser to use for CSV parsing
    enum ParserType {
        /// Used when column count is unknown (initially)
        case dynamic
        /// Used once we know the column count
        case fixed(capacity: Int)
        /// Fixed allocation without quotes parsing
        case fixedNoQuotes(capacity: Int)
    }
}
