# FastCSV
A speedy CSV parser for Swift

FastCSV is a simple CSV parser developed in Swift that aims to parse a file as quickly
as possible while being economical with memory and still being easy to use.

Speed is achieved by avoiding allocations as much as possible during parsing and only 
allocating if a value is actually used as well as reusing, which is why you should 
prefer using row-level processing rather than loading the whole file in memory. 

Memory consumption is kept down by pre-allocating buffers as much as possible with 
reasonable defaults and dynamic re-sizing.

All of this means that when iterating through the file, you should never keep a 
reference to a CSVValue object outside of its context.

```
for row in rows
{
    ...
}
```

⚠️⚠️⚠️ This project is still under construction!!!

## What works
* Parsing UTF-8 files
* Iterating through rows as arrays or dictionaries
* forEach convenience methods
* Fully loading file in memory
* Support for RFC 4180, TSV and custom (Only RFC 4180 compliance is currently covered)
* Custom Headers

## Doing
* Add more unit tests with emphasis on correctness
* Improve performance testing
* Improve Readme
    * Add examples

## Future improvements
* Writing to CSV
* Tolerant mode
* BOM
* Autodetection of delimiters
* SIMD for fast path
* Codable support

⚠️⚠️⚠️ This project is still under construction!!!