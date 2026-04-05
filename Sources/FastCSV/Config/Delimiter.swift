import Foundation

/// Controls the delimiters used for parsing and writing CSV files.
/// By default, it is RFC 4180 compliant.
public struct Delimiter {
    public let rowByte: UInt8
    public let fieldByte: UInt8
    public let quoteByte: UInt8

    /// The row delimiter as a Character.
    public var row: Character {
        Character(UnicodeScalar(rowByte))
    }

    /// The field delimiter as a Character.
    public var field: Character {
        Character(UnicodeScalar(fieldByte))
    }

    /// The quote delimiter as a Character.
    public var quote: Character {
        Character(UnicodeScalar(quoteByte))
    }

    public init(row: String = "\n",
                field: String = ",",
                quote: String = "\"") throws
    {
        guard row.count == 1, field.count == 1, quote.count == 1 else {
            throw CSVError.invalidDelimiter(
                message: "Delimiter must be a single ASCII character. Received: row='\(row)', field='\(field)', quote='\(quote)'",
            )
        }
        try self.init(row: Character(row), field: Character(field), quote: Character(quote))
    }

    public init(row: Character = "\n",
                field: Character = ",",
                quote: Character = "\"") throws
    {
        guard let rowByte = row.asciiValue,
              let fieldByte = field.asciiValue,
              let quoteByte = quote.asciiValue
        else {
            throw CSVError.invalidDelimiter(
                message: "Delimiter must be an ASCII character. Received: row='\(row)', field='\(field)', quote='\(quote)'",
            )
        }
        self.rowByte = rowByte
        self.fieldByte = fieldByte
        self.quoteByte = quoteByte
    }

    public init(row: UInt8 = 10,
                field: UInt8 = 44,
                quote: UInt8 = 34)
    {
        rowByte = row
        fieldByte = field
        quoteByte = quote
    }
}
