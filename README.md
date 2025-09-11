# FastCSV

A high-performance CSV parser for Swift

[![Swift 5](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

FastCSV is a high-performance CSV (Comma-Separated Values) parser written in Swift, designed to efficiently process large CSV files with minimal memory overhead. The library provides streaming capabilities and zero-copy parsing for optimal performance in production environments.

## Features

- **High-performance parsing** with specialized parsers for different use cases
- **Low memory footprint** through streaming and zero-copy techniques  
- **Streaming support** for processing large files without loading entire datasets into memory
- **Simple, intuitive API** with both array and dictionary-based iteration
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

### Basic Usage

**Array-based iteration:**
```swift
import FastCSV

let fileURL = URL(fileURLWithPath: "data.csv")
let rows = try FastCSV.makeArrayRows(fileURL: fileURL)

for row in rows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }
    
    // Process row values
    for value in row.values {
        let stringValue = try value.getString()
        print(stringValue ?? "")
    }
}
```

**Dictionary-based iteration:**
```swift
import FastCSV

let fileURL = URL(fileURLWithPath: "data.csv")
let rows = try FastCSV.makeDictionaryRows(fileURL: fileURL, hasHeaders: true)

for row in rows {
    if let error = row.error {
        print("Row error: \(error)")
        continue
    }
    
    // Access values by column name
    if let name = try row.values["name"]?.getString() {
        print("Name: \(name)")
    }
}
```

### Configuration

```swift
import FastCSV

// Custom configuration for optimal performance
let config = CSVParserConfig(
    delimiter: CSVFormat.tsv.delimiter,  // Tab-separated values
    readBufferSize: 512 * 1024,          // 512KB buffer
    assumeNoQuotes: true                 // Optimize for quote-free data
)

let rows = try FastCSV.makeArrayRows(
    fileURL: fileURL, 
    hasHeaders: true, 
    config: config
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

The library includes a benchmarking tool to measure performance:

```bash
swift run CSVBenchmark path/to/file.csv --assume-no-quotes --iterations 10
```

## Requirements

- **macOS**: 12.0+
- **iOS**: 15.0+
- **Swift**: 5.5+

## Development Status

**Note**: This project is currently in active development. While all tests pass and core functionality is stable, the API may change as I work toward version 1.0.

### Roadmap to 1.0

- Enhanced documentation and examples
- Expanded test coverage
- Generalized streaming support (string streams)
- CSV writer functionality
- Performance optimizations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.