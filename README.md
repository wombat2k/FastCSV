# FastCSV

A high-performance CSV parser and writer for Swift

[![CI](https://github.com/wombat2k/FastCSV/actions/workflows/ci.yml/badge.svg)](https://github.com/wombat2k/FastCSV/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

FastCSV is a high-performance CSV parser and writer for Swift. The parser processes large CSV files with minimal memory overhead through streaming and zero-copy techniques. The writer provides Codable round-tripping — read CSV into structs, transform, write back out.

## Features

### Reading
- **Decodable support** — decode CSV rows directly into Swift structs, only materializing the columns you need
- **Column mapping** — map CSV headers to struct properties at the call site, no CodingKeys required
- **High-performance parsing** with zero-copy techniques
- **Low memory footprint** through chunked streaming — constant memory regardless of file size
- **Three API tiers** — typed structs via `Decodable`, dictionary access by column name, or raw array iteration
- **Configurable delimiters** supporting standard CSV, TSV, and custom formats
- **Quote handling** with optional optimization for quote-free data
- **Error recovery** allowing processing to continue despite malformed rows
- **UTF-8 BOM detection** and automatic removal

### Writing
- **Encodable support** — write Swift structs directly to CSV with automatic header derivation
- **RFC 4180 quoting** — fields containing delimiters, quotes, or newlines are quoted automatically
- **Multiple output targets** — write to file path, URL, or string
- **Row-by-row or batch** — streaming writes via `CSVWriter` or one-shot via static methods
- **Round-trip fidelity** — read, transform, and write back with full type preservation

## Installation

Add FastCSV to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/wombat2k/FastCSV.git", from: "1.0.0")
]
```

## Quick Start

Define a struct, map the CSV columns to your property names, and iterate:

```swift
import FastCSV

struct BusRoute: Decodable {
    let route: String
    let name: String
    let monthTotal: Int
}

var rows = try FastCSV.makeRows(
    BusRoute.self,
    fromPath: "ridership.csv",
    columnMapping: [
        "routename": "name",
        "MonthTotal": "monthTotal",
    ]
)

try rows.forEach { route in
    print("\(route.name): \(route.monthTotal)")
}
```

Rows are decoded lazily — one at a time, not all at once. Memory stays constant regardless of file size.

## Column Mapping

The `columnMapping` parameter maps CSV header names to struct property names:

```swift
columnMapping: ["routename": "name"]
```

This means: the CSV column `routename` fills the struct property `name`.

You only need entries for columns whose names differ from your properties. Columns that already match (like `route` above) can be left out. Extra CSV columns are ignored.

If you prefer baking the mapping into the type, Swift's standard `CodingKeys` works too:

```swift
struct BusRoute: Decodable {
    let route: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case route
        case name = "routename"
    }
}

// No columnMapping needed
var rows = try FastCSV.makeRows(BusRoute.self, fromPath: "ridership.csv")
```

## Iterating

### forEach — process every row

Use `forEach` when you want to iterate through all rows. The callback receives a decoded struct directly:

```swift
try rows.forEach { route in
    print(route.name)
}
```

Use `return` to skip rows (not `continue` — you're inside a closure). Note that `forEach` always reads every row in the file, even when individual iterations return early.

### for-in — stop early with break

Use `for-in` when you need to stop before the end. Each element is a `Result<T, Error>`:

```swift
for result in rows {
    let route = try result.get()
    print(route.name)
    break
}
```

The `Result` type also enables per-row error handling:

```swift
for result in rows {
    switch result {
    case .success(let route): print(route.name)
    case .failure(let error): print("Skipping: \(error)")
    }
}
```

## Input Sources

All reading APIs accept file paths, URLs, in-memory `Data`, or `String`:

```swift
var rows = try FastCSV.makeRows(T.self, fromPath: "/path/to/file.csv")
var rows = try FastCSV.makeRows(T.self, fromURL: url)
var rows = try FastCSV.makeRows(T.self, fromData: csvData)
var rows = try FastCSV.makeRows(T.self, fromString: "name,age\nAlice,30\n")
```

## Raw Access

When you don't have a struct or don't know the schema:

```swift
// By position
let arrayRows = try FastCSV.makeArrayRows(fromPath: "data.csv")
for row in arrayRows {
    let name = try row[0].string
    let age = try row[1].int
}

// By column name
let dictRows = try FastCSV.makeDictionaryRows(fromPath: "data.csv")
for row in dictRows {
    let name = try row["name"]!.string
}
```

`CSVValue` provides typed accessors: `.string`, `.int`, `.double`, `.float`, `.bool`, `.date`, `.decimal`. Use the `IfPresent` variants (`.stringIfPresent`, `.intIfPresent`, etc.) when a field might be empty — they return `nil` instead of throwing.

Optional struct fields also decode empty CSV values as `nil`:

```swift
struct Person: Decodable {
    let name: String
    let age: Int?  // empty CSV field → nil
}
```

## Writing CSV

### Encodable structs

Headers are derived automatically from property names (or CodingKeys):

```swift
struct Output: Encodable {
    let name: String
    let age: Int
}

let people = [Output(name: "Alice", age: 30), Output(name: "Bob", age: 25)]

try FastCSV.writeRows(people, toPath: "output.csv")

let csv = try FastCSV.writeString(people)
```

### String arrays

```swift
try FastCSV.writeRows(
    [["Alice", "30"], ["Bob", "25"]],
    headers: ["name", "age"],
    toPath: "output.csv"
)
```

### Row-by-row streaming

```swift
let writer = CSVWriter()
try writer.writeHeaders(["name", "age"])
try writer.writeRow(["Alice", "30"])

if let csv = writer.toString() {
    print(csv)
}
```

`CSVWriter` also accepts a file path or URL in its initializer for streaming to disk.

## Configuration

### Custom delimiters

```swift
let tsv = CSVConfig(delimiter: CSVFormat.tsv.delimiter)
var rows = try FastCSV.makeRows(T.self, fromPath: "data.tsv", config: tsv)
```

Supported formats: CSV, TSV, semicolon-separated, or custom field/row/quote delimiters.

### No-quotes optimization

Skip quote detection for a ~9% speed boost when your data has no quoted fields:

```swift
let config = CSVConfig(assumeNoQuotes: true)
```

### Custom headers

For files without a header row:

```swift
var rows = try FastCSV.makeRows(
    T.self,
    fromPath: "data.csv",
    hasHeaders: false,
    headers: ["name", "age", "city"]
)
```

## Examples

The [Examples](Examples/) directory contains runnable examples using real CTA bus ridership data (40K rows). Each example is a standalone executable target:

```bash
cd Examples
swift run Filtering
swift run Aggregation
swift run Writing
swift run RawAccess
```

## Performance

FastCSV is optimized for high-throughput scenarios. Benchmarked against a 1.4GB [NHS prescription dataset](https://digital.nhs.uk/data-and-information/publications/statistical/practice-level-prescribing-data/presentation-level-july-2014) (10.3 million rows, 11 columns):

| API | Rows/sec | Notes |
|-----|----------|-------|
| Array iterator (no quotes) | 1.2M | Raw `CSVValue` access, 6 fields per row |
| Array iterator (standard) | 1.1M | Same access pattern, with quote detection |
| Decodable + columnMapping | 477K | Full struct decoding, 6 typed fields |

Memory stays constant regardless of file size — peak was 8.5MB (0.6% of the 1.4GB file).

The Decodable path is roughly 2x slower than raw array access with equivalent field access. This overhead comes from Swift's Codable protocol machinery (dynamic dispatch, `KeyedDecodingContainer`, `CodingKey` resolution per field per row) and is inherent to any Decoder implementation. For maximum throughput on very large files, use the array or dictionary iterators directly.

## Requirements

- **macOS**: 13.0+
- **iOS**: 15.0+
- **Swift**: 6.1+

## License

MIT License — see [LICENSE](LICENSE) for details.
