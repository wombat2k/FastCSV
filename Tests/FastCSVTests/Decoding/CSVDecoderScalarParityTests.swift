import Testing
@testable import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

/// The decoder parses scalars straight from bytes. These pin its accept/reject
/// behavior to what the stdlib `T(String)` initializers do on the
/// quote-stripped field, which is what the decoder used before.

private struct One<T: Decodable>: Decodable {
    let v: T
}

/// Decode a single field `raw` (written verbatim into the CSV) as `T`.
private func decodeField<T: Decodable>(_: T.Type, _ raw: String) -> T? {
    guard var rows = try? FastCSV.makeRows(One<T>.self, fromString: "v\n\(raw)\n") else { return nil }
    var out: T?
    do {
        try rows.forEach { out = $0.v }
    } catch {
        return nil
    }
    return out
}

/// What the old String path produced: strip one quote pair, un-double quotes, `T(String)`.
private func oracle<T: LosslessStringConvertible>(_: T.Type, _ raw: String) -> T? {
    var s = raw
    if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
        s = String(s.dropFirst().dropLast()).replacing("\"\"", with: "\"")
    } else if s == "\"" {
        s = ""
    }
    return T(s)
}

private let integerInputs = [
    "0", "1", "-1", "+1", "-0", "+0", "42", "007", "-", "+", "+-1", "--1", "1-",
    "1.0", "1e3", "0x10", "1_000", "١٢", "9223372036854775807", "9223372036854775808",
    "-9223372036854775808", "-9223372036854775809", "255", "256", "-128", "-129",
    "65535", "4294967295", "4294967296", "18446744073709551615", "18446744073709551616",
    "\"42\"", "\"-7\"", "\"\"", "\"", "\"4\"\"2\"", "\" 42\"", "\"42 \"",
]

private let floatingInputs = [
    "0", "-0", "1", "1.5", "-1.5", "+1.5", ".5", "5.", "1e3", "1E-3", "1e", "e3", "1.2.3",
    "inf", "-inf", "+inf", "INF", "infinity", "Infinity", "nan", "NaN", "-nan", "nan(0x1)", "snan",
    "0x1p3", "0x1.8p1", "0X1P-2", "0x", "1e400", "-1e400", "1e-400", "4.9e-324",
    "3.4028235e38", "3.5e38", "1.17549435e-38", "1e-46",
    "0.1", "123456789.123456789", "\"1,5\"", "1_0", "١.٥",
    "\"1.5\"", "\"-0\"", "\"\"", "\"", "\" 1.5\"", "\"1.5 \"",
]

private func sameFloat<F: BinaryFloatingPoint>(_ a: F?, _ b: F?) -> Bool {
    switch (a, b) {
    case (nil, nil): true
    case let (x?, y?): (x.isNaN && y.isNaN) || x == y && x.sign == y.sign
    default: false
    }
}

struct CSVDecoderScalarParityTests {
    @Test(arguments: integerInputs)
    func `Int matches Int(String)`(raw: String) {
        #expect(decodeField(Int.self, raw) == oracle(Int.self, raw))
    }

    @Test(arguments: integerInputs)
    func `Narrow and unsigned widths match T(String)`(raw: String) {
        #expect(decodeField(Int8.self, raw) == oracle(Int8.self, raw))
        #expect(decodeField(Int16.self, raw) == oracle(Int16.self, raw))
        #expect(decodeField(Int32.self, raw) == oracle(Int32.self, raw))
        #expect(decodeField(Int64.self, raw) == oracle(Int64.self, raw))
        #expect(decodeField(UInt.self, raw) == oracle(UInt.self, raw))
        #expect(decodeField(UInt8.self, raw) == oracle(UInt8.self, raw))
        #expect(decodeField(UInt16.self, raw) == oracle(UInt16.self, raw))
        #expect(decodeField(UInt32.self, raw) == oracle(UInt32.self, raw))
        #expect(decodeField(UInt64.self, raw) == oracle(UInt64.self, raw))
    }

    @Test(arguments: floatingInputs)
    func `Double matches Double(String)`(raw: String) {
        #expect(sameFloat(decodeField(Double.self, raw), oracle(Double.self, raw)))
    }

    @Test(arguments: floatingInputs)
    func `Float matches Float(String)`(raw: String) {
        #expect(sameFloat(decodeField(Float.self, raw), oracle(Float.self, raw)))
    }

    @Test
    func `Quoted Bool decodes`() {
        #expect(decodeField(Bool.self, "\"true\"") == true)
        #expect(decodeField(Bool.self, "\"N\"") == false)
        #expect(decodeField(Bool.self, "\"tru\"\"e\"") == nil)
    }

    @Test
    func `Empty numeric field is valueNotFound, junk is typeMismatch`() throws {
        var empty = try FastCSV.makeRows(One<Int>.self, fromString: "v\n\"\"\n")
        // A quoted-empty field is present but not a number.
        #expect {
            try empty.forEach { _ in }
        } throws: { error in
            guard case DecodingError.typeMismatch = error else { return false }
            return true
        }

        var junk = try FastCSV.makeRows(One<Double>.self, fromString: "v\n\"abc\"\n")
        #expect {
            try junk.forEach { _ in }
        } throws: { error in
            guard case let DecodingError.typeMismatch(_, ctx) = error else { return false }
            return ctx.debugDescription.contains("'abc'")
        }
    }
}
