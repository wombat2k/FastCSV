#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

// Apple FoundationEssentials gates `TimeZone.gmt` to iOS 16+ / macOS 13+;
// swift-foundation's FE on Linux has it. We need iOS 15 support, so on Apple
// we use the legacy `TimeZone(secondsFromGMT:)` initializer (works back to iOS 2).
// When iOS 15 support is dropped, collapse this to `TimeZone.gmt`.
private let gmtTimeZone: TimeZone = {
    #if canImport(Darwin)
        TimeZone(secondsFromGMT: 0)!
    #else
        TimeZone.gmt
    #endif
}()

/// Strategy for converting between `Date` and `String` for CSV fields.``
/// The `dateStrategy` is honored on both encode (writer) and decode (Decodable reader).
public struct CSVDateStrategy: Sendable {
    /// Convert a `Date` to its CSV string representation.
    public let format: @Sendable (Date) -> String

    /// Convert a CSV string into a `Date`. Throws if the string does not match
    /// the strategy's expected format.
    public let parse: @Sendable (String) throws -> Date

    /// Build a strategy from explicit format and parse closures. Use this for
    /// formats that no built-in `ParseableFormatStyle` covers.
    public init(
        format: @escaping @Sendable (Date) -> String,
        parse: @escaping @Sendable (String) throws -> Date,
    ) {
        self.format = format
        self.parse = parse
    }
}

public extension CSVDateStrategy {
    /// ISO 8601 date-only (`yyyy-MM-dd`) in GMT. The default for FastCSV.
    static let iso8601Date: CSVDateStrategy = .formatStyle(
        Date.ISO8601FormatStyle(timeZone: gmtTimeZone).year().month().day(),
    )

    /// Full ISO 8601 date-time (e.g. `2026-04-27T12:34:56Z`) in GMT.
    static let iso8601: CSVDateStrategy = .formatStyle(Date.ISO8601FormatStyle())

    /// Build a strategy from any `ParseableFormatStyle` whose input/output are `Date`/`String`.
    /// Most callers will pass a `Date.VerbatimFormatStyle`, `Date.ISO8601FormatStyle`,
    /// or `Date.FormatStyle`.
    static func formatStyle<S: ParseableFormatStyle & Sendable>(
        _ style: S,
    ) -> CSVDateStrategy where S.FormatInput == Date, S.FormatOutput == String, S.Strategy: Sendable {
        let strategy = style.parseStrategy
        return CSVDateStrategy(
            format: { style.format($0) },
            parse: { try strategy.parse($0) },
        )
    }
}
