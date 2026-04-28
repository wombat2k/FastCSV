// main.swift
// Read CSV data, transform it, and write it back out.
// Demonstrates the full read-transform-write round-trip.

import FastCSV
#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

// --- Read and transform: extract one route's history ---

struct BusRoute: Decodable {
    let route: String
    let name: String
    let monthBeginning: String
    let avgWeekdayRides: Double
    let monthTotal: Int
}

let inputMapping = [
    "routename": "name",
    "Month_Beginning": "monthBeginning",
    "Avg_Weekday_Rides": "avgWeekdayRides",
    "MonthTotal": "monthTotal",
]

/// The output struct — different shape from the input.
struct RouteHistory: Encodable {
    let year: String
    let month: String
    let avgWeekdayRides: Double
    let monthTotal: Int
}

/// Filter to Route 79 (Western — one of Chicago's busiest) and reshape.
var history: [RouteHistory] = []

var rows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: inputMapping)
try rows.forEach { route in
    guard route.route == "79" else { return }

    let parts = route.monthBeginning.split(separator: "/")
    history.append(RouteHistory(
        year: String(parts[2]),
        month: String(parts[0]),
        avgWeekdayRides: route.avgWeekdayRides,
        monthTotal: route.monthTotal,
    ))
}

// Write to a new CSV file.
try FastCSV.writeRows(history, toPath: "western-route-history.csv")
print("Wrote \(history.count) rows to western-route-history.csv")

// --- Write to a string instead of a file ---

let csv = try FastCSV.writeString(Array(history.prefix(5)))
print("\nFirst 5 rows as string:\n\(csv)")

// --- Row-by-row writing with CSVWriter ---

/// Useful when you want to stream output without buffering everything.
let writer = CSVWriter()

try writer.writeHeaders(["route", "name", "peak_month_total"])

/// Find each route's peak month and write it out.
var peakByRoute: [String: (name: String, peak: Int)] = [:]

var peakRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: inputMapping)
try peakRows.forEach { route in
    let existing = peakByRoute[route.route]
    if existing == nil || route.monthTotal > existing!.peak {
        peakByRoute[route.route] = (route.name, route.monthTotal)
    }
}

for (route, info) in peakByRoute.sorted(by: { $0.key < $1.key }).prefix(10) {
    try writer.writeRow([route, info.name, String(info.peak)])
}

if let output = writer.toString() {
    print("\nPeak ridership months (first 10 routes):\n\(output)")
}
