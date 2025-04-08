import Foundation

/// This struct controls the delimiters used for parsing CSV files.
/// It is used by the parser to determine how to split the data.
/// By default, it is RFC 4180 compliant.
public struct Delimiter: Sendable {
    let row: UInt8
    let field: UInt8
    let value: UInt8

    public init(row: UInt8 = UInt8(ascii: "\n"),
                field: UInt8 = UInt8(ascii: ","),
                value: UInt8 = UInt8(ascii: "\""))
    {
        self.row = row
        self.field = field
        self.value = value
    }
}
