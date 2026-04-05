// Aggregation.swift
// Accumulate statistics across 40K+ rows in constant memory.
// Nothing is loaded into an array — just running totals.

import FastCSV
import Foundation

struct BusRoute: Decodable {
    let route: String
    let name: String
    let monthBeginning: String
    let avgWeekdayRides: Double
    let avgSaturdayRides: Double
    let avgSundayHolidayRides: Double
    let monthTotal: Int

    enum CodingKeys: String, CodingKey {
        case route
        case name = "routename"
        case monthBeginning = "Month_Beginning"
        case avgWeekdayRides = "Avg_Weekday_Rides"
        case avgSaturdayRides = "Avg_Saturday_Rides"
        case avgSundayHolidayRides = "Avg_Sunday-Holiday_Rides"
        case monthTotal = "MonthTotal"
    }
}

// --- Total ridership by year ---

print("CTA bus ridership by year:")

// Year is the last 4 characters of the date string (MM/dd/yyyy).
var ridershipByYear: [String: Int] = [:]

var yearRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
try yearRows.forEach { route in
    let year = String(route.monthBeginning.suffix(4))
    ridershipByYear[year, default: 0] += route.monthTotal
}

for year in ridershipByYear.keys.sorted() {
    let total = ridershipByYear[year]!
    let millions = Double(total) / 1_000_000
    print("  \(year): \(String(format: "%.1f", millions))M rides")
}

// --- All-time busiest routes ---

print("\nTop 15 routes by all-time total ridership:")

var totalByRoute: [String: (name: String, total: Int)] = [:]

var routeRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
try routeRows.forEach { route in
    var entry = totalByRoute[route.route] ?? (name: route.name, total: 0)
    entry.total += route.monthTotal
    totalByRoute[route.route] = entry
}

let ranked = totalByRoute.values.sorted { $0.total > $1.total }

for (i, entry) in ranked.prefix(15).enumerated() {
    let billions = Double(entry.total) / 1_000_000_000
    print("  \(i + 1). \(entry.name): \(String(format: "%.2f", billions))B rides")
}

// --- Average weekday ridership across the entire system by month ---

print("\nSystem-wide average weekday ridership (2025):")

var monthlyTotals: [(month: String, weekdayRides: Double)] = []
var currentMonth = ""
var currentTotal = 0.0

var monthlyRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
try monthlyRows.forEach { route in
    guard route.monthBeginning.hasSuffix("2025") else { return }

    if route.monthBeginning != currentMonth {
        if !currentMonth.isEmpty {
            monthlyTotals.append((currentMonth, currentTotal))
        }
        currentMonth = route.monthBeginning
        currentTotal = 0
    }
    currentTotal += route.avgWeekdayRides
}

// Don't forget the last month.
if !currentMonth.isEmpty {
    monthlyTotals.append((currentMonth, currentTotal))
}

for entry in monthlyTotals {
    print("  \(entry.month): \(String(format: "%.0f", entry.weekdayRides)) avg weekday rides")
}
