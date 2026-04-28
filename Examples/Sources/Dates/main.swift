// main.swift
// Decode and encode Date fields with CSVDateStrategy.
// The CTA dataset stores Month_Beginning as MM/dd/yyyy — a custom format,
// not ISO 8601. This example shows how to wire that up.

import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

// --- Build a strategy for the CTA's MM/dd/yyyy column ---

let ctaStyle = Date.VerbatimFormatStyle(
    format: "\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)",
    locale: .init(identifier: "en_US_POSIX"),
    timeZone: .gmt,
    calendar: .init(identifier: .gregorian),
)
let ctaStrategy = CSVDateStrategy.formatStyle(ctaStyle)

// --- Decode: typed Date instead of String ---

struct Ridership: Decodable {
    let route: String
    let monthBeginning: Date
    let monthTotal: Int
}

let inputMapping = [
    "Month_Beginning": "monthBeginning",
    "MonthTotal": "monthTotal",
]

let parserConfig = CSVParserConfig(dateStrategy: ctaStrategy)

var rows = try FastCSV.makeRows(
    Ridership.self,
    fromPath: "cta-ridership.csv",
    columnMapping: inputMapping,
    config: parserConfig,
)

// Find Route 79's peak month using real Date comparisons.
var peakMonth: Date?
var peakRides = 0

try rows.forEach { row in
    guard row.route == "79" else { return }
    if row.monthTotal > peakRides {
        peakRides = row.monthTotal
        peakMonth = row.monthBeginning
    }
}

if let peakMonth {
    let displayed = ctaStyle.format(peakMonth)
    print("Route 79 peak: \(peakRides) rides during month starting \(displayed)")
}

// --- Encode: write Dates back out using the same strategy ---

struct PeakRecord: Encodable {
    let route: String
    let peakMonth: Date
    let monthTotal: Int
}

let writerConfig = CSVWriterConfig(dateStrategy: ctaStrategy)
let records = [
    PeakRecord(route: "79", peakMonth: peakMonth ?? .now, monthTotal: peakRides),
]
let csv = try FastCSV.writeString(records, config: writerConfig)
print("\nEncoded back out (same strategy):\n\(csv)")

// --- Default ISO 8601 (yyyy-MM-dd) needs no config ---

struct Sale: Codable {
    let item: String
    let date: Date
}

var isoRows = try FastCSV.makeRows(Sale.self, fromString: "item,date\nWidget,2026-03-15\n")
try isoRows.forEach { sale in
    print("\nDefault ISO 8601 decoded: item=\(sale.item) date=\(sale.date)")
}
