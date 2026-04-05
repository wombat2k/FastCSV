// BasicUsage.swift
// Read CTA ridership data into typed Swift structs using Decodable.

import FastCSV
import Foundation

// Step 1: Define a struct matching the CSV columns.
// Use CodingKeys to map CSV headers to Swift property names.
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

// Step 2: Read rows from a CSV file.
// Rows are decoded lazily — one at a time, not all at once.
var rows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")

// Step 3: Iterate.
// Use forEach when you want to process every row. It handles
// Result unwrapping for you — the callback receives a decoded struct directly.
try rows.forEach { route in
    if route.monthTotal > 1_000_000 {
        print("\(route.name) — \(route.monthBeginning): \(route.monthTotal) rides")
    }
}

// Use for-in when you need to stop early. Each element is a
// Result<T, Error>, so you call .get() to unwrap it yourself.
print("\nFirst 5 routes:")

var rows2 = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
var count = 0
for result in rows2 {
    let route = try result.get()
    print("  \(route.name) (\(route.route))")

    count += 1
    if count >= 5 { break }
}

// You don't need CodingKeys if your property names match the CSV headers exactly.
// Extra columns are ignored — you only decode what you declare.
struct RouteTotal: Decodable {
    let route: String
    let routename: String
    let MonthTotal: Int
}

var totals = try FastCSV.makeRows(RouteTotal.self, fromPath: "cta-ridership.csv")
print("\nWithout CodingKeys:")
count = 0
for result in totals {
    let row = try result.get()
    print("  \(row.routename): \(row.MonthTotal)")

    count += 1
    if count >= 3 { break }
}
