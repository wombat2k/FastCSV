# FastCSV

A high-performance CSV parser for Swift

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

FastCSV is a high-performance CSV (Comma-Separated Values) parser written in Swift, designed to efficiently process large CSV files with minimal memory overhead. The library provides streaming capabilities and zero-copy parsing for optimal performance in production environments.

## Features

- **Decodable support** — decode CSV rows directly into Swift structs, only materializing the columns you need
- **High-performance parsing** with specialized parsers for different use cases
- **Low memory footprint** through streaming and zero-copy techniques
- **Streaming support** for processing large files without loading entire datasets into memory
- **Three API tiers** — typed structs via `Decodable`, dictionary access by column name, or raw array iteration
- **Configurable delimiters** supporting standard CSV, TSV, and custom formats
- **Quote handling** with optional optimization for quote-free data
- **Error recovery** allowing processing to continue despite malformed rows
- **UTF-8 BOM detection** and automatic removal

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

var people = try FastCSV.makeRows(Person.self, from: "data.csv")
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
for result in try FastCSV.makeRows(Person.self, from: "data.csv") {
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

let rows = try FastCSV.makeArrayRows(fileURL: URL(fileURLWithPath: "data.csv"))

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

let rows = try FastCSV.makeDictionaryRows(fileURL: URL(fileURLWithPath: "data.csv"), hasHeaders: true)

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

### Configuration

All three API tiers accept the same configuration options:

```swift
import FastCSV

let config = CSVParserConfig(
    delimiter: CSVFormat.tsv.delimiter,  // Tab-separated values
    readBufferSize: 512 * 1024,          // 512KB buffer
    assumeNoQuotes: true                 // Optimize for quote-free data
)

var people = try FastCSV.makeRows(
    Person.self,
    from: "data.tsv",
    config: config
)
```

Custom headers can be provided for files without a header row:

```swift
var people = try FastCSV.makeRows(
    Person.self,
    from: "data.csv",
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

FastCSV is optimized for high-throughput scenarios with multiple parser implementations:

- **Dynamic Column Parser**: For files with unknown column counts
- **Fixed Column Parser**: Optimized when column count is known
- **Fixed Column No-Quotes Parser**: Maximum performance for quote-free data

The Decodable layer adds minimal overhead — it wraps the array iterator directly with a pre-built column index map, avoiding the dictionary allocation that the dictionary iterator requires. Only columns matching your struct's properties are decoded.

## Requirements

- **macOS**: 12.0+
- **iOS**: 15.0+
- **Swift**: 6.0+

## Development Status

**Note**: This project is currently in active development. While all tests pass and core functionality is stable, the API may still change.

### Upcoming features
- CSVValue refactor
- Strict concurrency compliance
- String input support
- Performance optimizations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.