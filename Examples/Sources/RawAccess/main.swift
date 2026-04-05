// main.swift
// Array and dictionary iterators for when you don't know (or don't want
// to define) the schema upfront. Useful for CSV exploration and dynamic data.

import FastCSV
import Foundation

// --- Array access: rows as [CSVValue] ---

/// When you just want positional access to fields.
let arrayRows = try FastCSV.makeArrayRows(fromPath: "cta-ridership.csv")

// Headers are available on the iterator.
print("Columns: \(arrayRows.headers.joined(separator: ", "))")

var count = 0
for row in arrayRows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }

    // Access by position. CSVValue has typed accessors.
    let name = try row[1].string
    let total = try row[6].int
    print("\(name): \(total)")

    count += 1
    if count >= 5 { break }
}

// --- Dictionary access: rows as [String: CSVValue] ---

// When you want column-name access without defining a struct.
print("\nDictionary access:")

let dictRows = try FastCSV.makeDictionaryRows(fromPath: "cta-ridership.csv")

count = 0
for row in dictRows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }

    // Access by column name.
    let name = try row["routename"]!.string
    let weekday = try row["Avg_Weekday_Rides"]!.double
    let total = try row["MonthTotal"]!.int

    if weekday > 20000 {
        print("  High-traffic: \(name) — \(weekday) avg weekday, \(total) monthly total")
    }

    count += 1
    if count >= 200 { break }
}

// --- Working with CSVValue types ---

print("\nCSVValue type demo:")

/// Parse a small CSV from a string to demonstrate value access patterns.
let csv = """
item,quantity,price,in_stock,notes
Widget,100,9.99,true,Standard widget
Gadget,0,24.50,false,
Doohickey,42,3.75,true,"Has a comma, in the name"
"""

let rows = try FastCSV.makeArrayRows(fromString: csv)

for row in rows {
    let item = try row[0].string
    let quantity = try row[1].int
    let price = try row[2].double
    let inStock = try row[3].bool

    // Optional accessor — returns nil for empty fields instead of throwing.
    let notes = try row[4].stringIfPresent ?? "(no notes)"

    print("  \(item): qty=\(quantity), $\(price), "
        + "in stock=\(inStock), notes=\(notes)")
}
