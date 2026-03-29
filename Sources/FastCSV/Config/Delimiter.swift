import Foundation

/// This struct controls the delimiters used for parsing CSV files.
/// It is used by the parser to determine how to split the data.
/// By default, it is RFC 4180 compliant.
public struct Delimiter: Sendable {
    let row: UInt8
    let field: UInt8
    let quote: UInt8

    public init(row: String = "\n", // LF
                field: String = ",", // comma
                quote: String = "\"") // double quote
                throws {

        let message = "Delimiter characters must be a single ASCII character. Received: row='\(row)', field='\(field)', quote='\(quote)'"
        
        guard row.count == 1, field.count == 1, quote.count == 1 else {
            throw CSVError.invalidDelimiter(message: message)
        }
        
        try self.init(row: Character(row), field: Character(field), quote: Character(quote))
    }

    public init(row: Character = "\n", // LF
                field: Character = ",", // comma
                quote: Character = "\"") // double quote
    throws {
        let message = "Delimiter characters must be an ASCII character. Received: row='\(row)', field='\(field)', quote='\(quote)'"    
        
        if let rowByte = row.asciiValue, let fieldByte = field.asciiValue, let quoteByte = quote.asciiValue {
            self.row = rowByte
            self.field = fieldByte
            self.quote = quoteByte
        }
        else {
            throw CSVError.invalidDelimiter(message: message)
        }
    }
    
    public init(row: UInt8 = 10, // LF
                field: UInt8 = 44, // comma
                quote: UInt8 = 34) // double quote
    {
        self.row = row
        self.field = field
        self.quote = quote
    }
}
