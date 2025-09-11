import Foundation

/// High-performance streaming CSV parser that returns rows on demand
public class FastCSV {
    // MARK: - Header Processing

    /// Process header information based on first row and configuration
    /// - Parameters:
    ///   - firstRow: First row values from the CSV file
    ///   - hasHeaders: Whether the file has headers in the first row
    ///   - customHeaders: Custom headers provided by the user, if any
    /// - Returns: Tuple containing processed headers, whether to skip first row, and header count
    /// - Throws: CSVError if header validation fails
    private static func processHeaders(firstRow: [CSVValue], hasHeaders: Bool, customHeaders: [String]) throws ->
        (headers: [String], skipFirstRow: Bool, headerCount: Int)
    {
        // Process directly with the first row
        if !customHeaders.isEmpty {
            // If custom headers are provided, use them and validate count
            if customHeaders.count != firstRow.count {
                throw CSVError.invalidCSV(message: "Header count (\(customHeaders.count)) does not match the number of fields in the first row (\(firstRow.count)).")
            }

            let processedHeaders = processEmptyHeaders(headers: customHeaders)

            // If custom headers are provided AND file has headers,
            // we should skip the first row when reading data
            return (processedHeaders, hasHeaders, processedHeaders.count)
        } else if hasHeaders {
            // If hasHeaders=true, use first row as headers
            let extractedHeaders = try firstRow.map { try $0.getString() ?? "" }

            let processedHeaders = processEmptyHeaders(headers: extractedHeaders)

            return (processedHeaders, true, processedHeaders.count)
        } else {
            // No headers in file or provided, generate auto-numbered columns
            let emptyHeaders = Array(repeating: "", count: firstRow.count)
            let processedHeaders = processEmptyHeaders(headers: emptyHeaders)
            return (processedHeaders, false, firstRow.count)
        }
    }

    /// Removes UTF-8 BOM from the first field of a row if present
    /// - Parameter row: The CSV row to process
    /// - Returns: A new row with BOM removed if it was present
    private static func removeUTF8BOMIfPresent(fromRow row: [CSVValue]) -> [CSVValue] {
        var result = row

        // Check if there's at least one field and if the first field contains a BOM
        if !result.isEmpty,
           let firstValue = try? result[0].getString(),
           firstValue.hasPrefix("\u{FEFF}")
        {
            // Remove BOM from the first field
            let cleanedField = firstValue.dropFirst(1)
            result[0] = CSVValue(bytes: Array(cleanedField.utf8))
        }

        return result
    }

    /// Process headers by replacing empty values with auto-generated column names
    /// - Parameter headers: Array of header strings to process
    /// - Returns: Array of processed headers with no empty values
    private static func processEmptyHeaders(headers: [String]) -> [String] {
        return headers.enumerated().map { index, header in
            header.isEmpty ? "column_\(index + 1)" : header // Using 1-based indexing for readability
        }
    }

    // MARK: - Static Iterators

    /// Performs common initialization for static CSV processing
    /// - Parameters:
    ///   - fileURL: URL to the CSV file
    ///   - hasHeaders: Whether the first row contains headers
    ///   - headers: Custom headers to use
    ///   - config: Configuration options for CSV parsing
    /// - Returns: Tuple containing initialized parameters needed for iterators
    /// - Throws: Error if the file cannot be accessed or is invalid
    private static func initialize(fileURL: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws ->
        (fileURL: URL, config: CSVParserConfig, headers: [String], skipFirstRow: Bool, headerCount: Int)
    {
        let finalConfig = config ?? CSVParserConfig()

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        // Read the first row to determine column count
        let rowIterator = CSVRowIterator(reader: fileHandle, skipFirstRow: false, config: finalConfig)
        var valueArrayIterator = CSVArrayIterator(rowIterator: rowIterator, headerCount: 0)

        defer { valueArrayIterator.cleanup() }

        guard let firstRowResult = valueArrayIterator.next() else {
            throw CSVError.invalidFile(message: "No data found in the file.")
        }

        if let error = firstRowResult.error {
            throw error
        }

        // Process headers
        let headerSettings = try processHeaders(firstRow: firstRowResult.values, hasHeaders: hasHeaders, customHeaders: headers)

        return (fileURL, finalConfig, headerSettings.headers, headerSettings.skipFirstRow, headerSettings.headerCount)
    }

    /// Static method to create an iterator over CSV rows as arrays of CSVValue
    /// - Parameters:
    ///   - path: String path to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty)
    ///   - config: Configuration options for CSV parsing (default: nil)
    /// - Returns: Iterator that yields rows as arrays of CSVValue
    /// - Throws: Error if the file cannot be accessed or is invalid
    public static func makeArrayRows(path: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        return try makeArrayRows(fileURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Static method to create an iterator over CSV rows as arrays of CSVValue
    /// - Parameters:
    ///   - fileURL: URL to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty)
    ///   - config: Configuration options for CSV parsing (default: nil)
    /// - Returns: Iterator that yields rows as arrays of CSVValue
    /// - Throws: Error if the file cannot be accessed or is invalid
    public static func makeArrayRows(fileURL: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        let initParams = try initialize(fileURL: fileURL, hasHeaders: hasHeaders, headers: headers, config: config)

        let fileHandle = try FileHandle(forReadingFrom: initParams.fileURL)
        let rowIterator = CSVRowIterator(reader: fileHandle, skipFirstRow: initParams.skipFirstRow, columnCount: initParams.headerCount, config: initParams.config)

        return CSVArrayIterator(
            rowIterator: rowIterator,
            headerCount: initParams.headerCount,
            skipFirstRow: initParams.skipFirstRow
        )
    }

    /// Static method to create an iterator over CSV rows as dictionaries with header keys
    /// - Parameters:
    ///   - path: String path to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty)
    ///   - config: Configuration options for CSV parsing (default: nil)
    /// - Returns: Iterator that yields rows as dictionaries of String -> CSVValue
    /// - Throws: Error if the file cannot be accessed or is invalid
    public static func makeDictionaryRows(path: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        return try makeDictionaryRows(fileURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Static method to create an iterator over CSV rows as dictionaries with header keys
    /// - Parameters:
    ///   - fileURL: URL to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty)
    ///   - config: Configuration options for CSV parsing (default: nil)
    /// - Returns: Iterator that yields rows as dictionaries of String -> CSVValue
    /// - Throws: Error if the file cannot be accessed or is invalid
    public static func makeDictionaryRows(fileURL: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        let initParams = try initialize(fileURL: fileURL, hasHeaders: hasHeaders, headers: headers, config: config)
        let valueArrayIterator = try makeArrayRows(fileURL: fileURL, hasHeaders: hasHeaders, headers: headers, config: config)

        return CSVDictionaryIterator(valueArrayIterator: valueArrayIterator, headers: initParams.headers)
    }
}
