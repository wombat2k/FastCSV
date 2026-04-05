// Filtering.swift
// Query CTA ridership data using lazy iteration — rows are processed
// one at a time, so memory stays constant regardless of file size.

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

// --- Busiest single months across all routes ---

print("Top 10 busiest route-months:")

var topMonths: [(String, String, Int)] = []

var rows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
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

var weekendRows = try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv")
try weekendRows.forEach { route in
    guard route.monthBeginning == "01/01/2026" else { return }

    if route.avgSaturdayRides == 0 && route.avgSundayHolidayRides == 0 {
        print("  \(route.name) (\(route.route)) — weekday avg: \(route.avgWeekdayRides)")
    }
}

// --- COVID impact: compare Jan 2020 vs Jan 2021 for a single route ---

print("\nRoute 9 (Ashland) — COVID impact:")

var jan2020: BusRoute?
var jan2021: BusRoute?

for result in try FastCSV.makeRows(BusRoute.self, fromPath: "cta-ridership.csv") {
    let route = try result.get()
    guard route.route == "9" else { continue }

    if route.monthBeginning == "01/01/2020" { jan2020 = route }
    if route.monthBeginning == "01/01/2021" { jan2021 = route }
    if jan2020 != nil && jan2021 != nil { break }
}

if let before = jan2020, let during = jan2021 {
    let change = Double(during.monthTotal - before.monthTotal) / Double(before.monthTotal) * 100
    print("  Jan 2020: \(before.monthTotal) rides")
    print("  Jan 2021: \(during.monthTotal) rides")
    print("  Change: \(String(format: "%.1f", change))%")
}
