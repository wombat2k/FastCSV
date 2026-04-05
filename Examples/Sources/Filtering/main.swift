// main.swift
// Query CTA ridership data using lazy iteration.

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
}

let mapping = [
    "routename": "name",
    "Month_Beginning": "monthBeginning",
    "Avg_Weekday_Rides": "avgWeekdayRides",
    "Avg_Saturday_Rides": "avgSaturdayRides",
    "Avg_Sunday-Holiday_Rides": "avgSundayHolidayRides",
    "MonthTotal": "monthTotal",
]

// --- Simple filter: months with over 1M rides ---

print("Months exceeding 1M rides:")

var simpleRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: mapping)
try simpleRows.forEach { route in
    guard route.monthTotal > 1_000_000 else { return }
    print("  \(route.name) — \(route.monthBeginning): \(route.monthTotal) rides")
}

// --- Busiest single months across all routes ---

print("\nTop 10 busiest route-months:")

var topMonths: [(String, String, Int)] = []

var rows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: mapping)
try rows.forEach { route in
    // Keep a sorted top-10 list as we stream through.
    if topMonths.count < 10 || route.monthTotal > topMonths.last!.2 {
        topMonths.append((route.name, route.monthBeginning, route.monthTotal))
        topMonths.sort { $0.2 > $1.2 }
        if topMonths.count > 10 { topMonths.removeLast() }
    }
}

for (i, entry) in topMonths.enumerated() {
    print("  \(i + 1). \(entry.0) — \(entry.1): \(entry.2) rides")
}

// --- Routes with no weekend service ---

print("\nRoutes with no Saturday or Sunday service (Jan 2026):")

var weekendRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: mapping)
try weekendRows.forEach { route in
    guard route.monthBeginning == "01/01/2026" else { return }

    if route.avgSaturdayRides == 0, route.avgSundayHolidayRides == 0 {
        print("  \(route.name) (\(route.route)) — weekday avg: \(route.avgWeekdayRides)")
    }
}

// --- COVID impact: compare Jan 2020 vs Jan 2021 for a single route ---
// Uses for-in because we need to break early once both months are found.

print("\nRoute 9 (Ashland) — COVID impact:")

var jan2020: BusRoute?
var jan2021: BusRoute?

for result in try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv", columnMapping: mapping) {
    let route = try result.get()
    guard route.route == "9" else { continue }

    if route.monthBeginning == "01/01/2020" { jan2020 = route }
    if route.monthBeginning == "01/01/2021" { jan2021 = route }
    if jan2020 != nil, jan2021 != nil { break }
}

if let before = jan2020, let during = jan2021 {
    let change = Double(during.monthTotal - before.monthTotal) / Double(before.monthTotal) * 100
    print("  Jan 2020: \(before.monthTotal) rides")
    print("  Jan 2021: \(during.monthTotal) rides")
    print("  Change: \(String(format: "%.1f", change))%")
}
