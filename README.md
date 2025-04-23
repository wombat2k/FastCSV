# FastCSV

A speedy CSV parser for Swift

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

FastCSV is a high-performance CSV (Comma-Separated Values) parser written in Swift. It's designed to efficiently handle large CSV files with minimal memory overhead.

## Features

- 🚀 High-performance parsing
- 💾 Low memory footprint
- 🔄 Streaming support
- 📊 Custom delimiter support
- 🧩 Simple, easy-to-use API

## Installation

### Swift Package Manager

Add FastCSV to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wombat2k/FastCSV.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import FastCSV

/* For a file that looks like this
name,age,city
John,30,New York
Alice,25,San Francisco
*/

do {
    let parser = try FastCSV(urlPath: "./data.csv")
    var rows = 
    for row in parser {
        print(row) // ["John", "30", "New York"], etc.
    }
} catch {
    print("Error parsing CSV: \(error)")
}
```

### Reading from a file

```swift
do {
    let parser = try CSVParser(url: fileURL)
    
    // Access by row
    for row in parser {
        // Process each row
    }
    
    // Access by column name
    if let headers = parser.headers {
        for row in parser {
            let name = row[headers[0]]
            let age = row[headers[1]]
            // ...
        }
    }
} catch {
    print("Error parsing CSV: \(error)")
}
```

### Configuration

```swift
let config = CSVConfiguration(
    delimiter: ";",
    quoteCharacter: "'",
    hasHeaderRow: true
)

let parser = try CSVParser(string: csvData, configuration: config)
```

## API Reference

### CSVParser

The main class for parsing CSV data.

#### Initialization

- `init(string:configuration:)`: Initialize with a string
- `init(url:configuration:)`: Initialize with a file URL
- `init(data:configuration:)`: Initialize with Data

#### Properties

- `headers`: Array of header strings if available
- `rowCount`: Number of rows in the CSV

#### Methods

- `next()`: Get the next row as an array of strings
- `reset()`: Reset the parser to the beginning

### CSVConfiguration

Configure the parser behavior.

- `delimiter`: Character used to separate values (default: ",")
- `quoteCharacter`: Character used for quoting values (default: "\"")
- `hasHeaderRow`: Whether the first row contains headers (default: false)
- `trimFields`: Whether to trim whitespace from fields (default: true)

## Performance

FastCSV is optimized for performance and can handle large CSV files efficiently. Internal benchmarks show it's significantly faster than many popular CSV parsers.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

Your Name - [@yourusername](https://twitter.com/yourusername)

Project Link: [https://github.com/yourusername/FastCSV](https://github.com/yourusername/FastCSV)

