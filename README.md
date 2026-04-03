# FastCSV

A high-performance CSV parser and writer for Swift

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

FastCSV is a high-performance CSV (Comma-Separated Values) parser and writer for Swift. The parser is designed to efficiently process large CSV files with minimal memory overhead through streaming and zero-copy techniques. The writer provides convenient Codable round-tripping — read CSV into structs, transform, write back out.

## Features

### Reading
- **Decodable support** — decode CSV rows directly into Swift structs, only materializing the columns you need
- **High-performance parsing** with zero-copy techniques
- **Low memory footprint** through chunked streaming — constant memory regardless of file size
- **Three API tiers** — typed structs via `Decodable`, dictionary access by column name, or raw array iteration
- **Configurable delimiters** supporting standard CSV, TSV, and custom formats
- **Quote handling** with optional optimization for quote-free data
- **Error recovery** allowing processing to continue despite malformed rows
- **UTF-8 BOM detection** and automatic removal

### Writing
- **Encodable support** — write Swift structs directly to CSV with automatic header derivation from CodingKeys
- **RFC 4180 quoting** — fields containing delimiters, quotes, or newlines are quoted automatically
- **Multiple output targets** — write to file path, URL, or string
- **Row-by-row or batch** — streaming writes via `CSVWriter` or one-shot via static methods
- **Round-trip fidelity** — read, transform, and write back with full type preservation

## Installation

### Swift Package Manager

Add FastCSV to your project using Swift Package Manager by adding the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/wombat2k/FastCSV.git", from: "1.0.0")
]
```

## Usage

### Decodable (Recommended)

Define a struct matching the columns you care about. Extra CSV columns are ignored — only matched columns are decoded, so you pay no cost for columns you don't use.

```swift
import FastCSV

struct Person: Decodable {
    let name: String
    let age: Int
}

var people = try FastCSV.makeRows(Person.self, fromPath: "data.csv")
try people.forEach { person in
    print(person.name, person.age)
}
```

Each row is decoded lazily as you iterate. Optional fields decode as `nil` for empty CSV values:

```swift
struct PersonWithOptional: Decodable {
    let name: String
    let age: Int?  // empty CSV field → nil
}
```

For per-row error handling, use the `Result`-based `for-in` loop:

```swift
for result in try FastCSV.makeRows(Person.self, fromPath: "data.csv") {
    switch result {
    case .success(let person):
        print(person.name)
    case .failure(let error):
        print("Skipping row: \(error)")
    }
}
```

### Array-based iteration

```swift
import FastCSV

let rows = try FastCSV.makeArrayRows(fromPath: "data.csv")

for row in rows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }

    for value in row.values {
        let stringValue = try value.stringIfPresent()
        print(stringValue ?? "")
    }
}
```

### Dictionary-based iteration

```swift
import FastCSV

let rows = try FastCSV.makeDictionaryRows(fromPath: "data.csv", hasHeaders: true)

for row in rows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }

    if let name = try row.values["name"]?.stringIfPresent() {
        print("Name: \(name)")
    }
}
```

### String and Data input

All three API tiers also accept in-memory input — no file needed:

```swift
// From a string
let csv = "name,age\nAlice,30\nBob,25\n"
var people = try FastCSV.makeRows(Person.self, fromString: csv)

// From Data
let data = Data(csv.utf8)
var people = try FastCSV.makeRows(Person.self, fromData: data)
```

### Writing CSV (Encodable)

Write an array of `Encodable` structs to CSV. Headers are derived automatically from CodingKeys. Make your structs `Codable` to support both reading and writing:

```swift
struct Person: Codable {
    let name: String
    let age: Int
}

let people = [
    Person(name: "Alice", age: 30),
    Person(name: "Bob", age: 25),
]

// Write to file
try FastCSV.writeRows(people, toPath: "output.csv")

// Write to string
let csv = try FastCSV.writeString(people)
// "name,age\nAlice,30\nBob,25\n"
```

Optional fields encode as empty CSV values, bools as `"true"`/`"false"`, dates using the configured formatter (default: `yyyy-MM-dd`).

### Writing CSV (String Arrays)

```swift
try FastCSV.writeRows(
    [["Alice", "30"], ["Bob", "25"]],
    headers: ["name", "age"],
    toPath: "output.csv"
)
```

### Row-by-Row Writing

For streaming writes or when rows are generated incrementally:

```swift
let writer = try CSVWriter(toPath: "output.csv")
try writer.writeRow(Person(name: "Alice", age: 30, score: 95.5))
try writer.writeRow(Person(name: "Bob", age: 25, score: 87.3))
writer.close()
```

### Configuration

#### Reading

All three reading API tiers accept the same configuration options:

```swift
import FastCSV

let config = CSVParserConfig(
    delimiter: CSVFormat.tsv.delimiter,  // Tab-separated values
    readBufferSize: 512 * 1024,          // 512KB buffer
    assumeNoQuotes: true                 // Optimize for quote-free data
)

var people = try FastCSV.makeRows(
    Person.self,
    fromPath: "data.tsv",
    config: config
)
```

#### Writing

```swift
let config = CSVWriterConfig(
    delimiter: CSVFormat.tsv.delimiter  // Tab-separated output
)

try FastCSV.writeRows(people, toPath: "output.tsv", config: config)
```

Custom headers can be provided for files without a header row:

```swift
var people = try FastCSV.makeRows(
    Person.self,
    fromPath: "data.csv",
    hasHeaders: false,
    headers: ["name", "age", "city"]
)
```

### Supported Formats

- **CSV**: Comma-separated values with double quotes
- **TSV**: Tab-separated values
- **Semicolon-separated**: Common in European locales
- **Custom**: Define your own field, row, and quote delimiters

## Performance

FastCSV is optimized for high-throughput scenarios.

The Decodable layer adds minimal overhead — it wraps the array iterator directly with a pre-built column index map, avoiding the dictionary allocation that the dictionary iterator requires. Only columns matching your struct's properties are decoded.

## Requirements

- **macOS**: 12.0+
- **iOS**: 15.0+
- **Swift**: 6.0+

## Development Status

**Note**: This project is currently in active development. While all tests pass and core functionality is stable, the API may still change.

### Upcoming features
- Performance optimizations (SIMD exploration)
- Multi-GB stress testing

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.