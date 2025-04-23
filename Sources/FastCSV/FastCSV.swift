import Foundation

/// High-performance streaming CSV parser that returns rows on demand
public class FastCSV {
    // CSV metadata
    private var _headers: [String] = []
    public var headers: [String] { return _headers }
    let headerCount: Int

    // CSV source configuration
    private let fileURL: URL
    private let config: CSVParserConfig

    // Track if we should skip the first row when reading data
    private let skipFirstRow: Bool

    // MARK: - Initializers

    /// Initialize a FastCSV instance that reads from a file path
    /// - Parameters:
    ///   - path: String path to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty, will read from first row if hasHeaders is true)
    ///   - config: Configuration options for CSV parsing (default: nil, will use standard values)
    /// - Throws: Error if the file cannot be accessed
    public convenience init(path: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws {
        try self.init(fileURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Initialize a FastCSV instance that reads from a file URL
    /// - Parameters:
    ///   - fileURL: URL to the CSV file
    ///   - hasHeaders: Whether the first row contains headers (default: true)
    ///   - headers: Custom headers to use (default: empty, will read from first row if hasHeaders is true)
    ///   - config: Configuration options for CSV parsing (default: nil, will use standard values)
    /// - Throws: Error if the file cannot be accessed
    public init(fileURL: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws {
        self.fileURL = fileURL
        self.config = config ?? CSVParserConfig()

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        // Read the first row in order to determine the count of columns
        // Since we don't know the number of columns in advance, we need to use the
        // dynamic parser which is more inefficient but we only need to do it once.
        let rowIterator = CSVRowIterator(fileHandle: fileHandle, skipFirstRow: false, config: self.config)
        var valueArrayIterator = CSVArrayIterator(rowIterator: rowIterator, headerCount: 0)

        // Required because we only read the first row
        defer { valueArrayIterator.cleanup() }

        guard let firstRowResult = valueArrayIterator.next() else {
            throw CSVError.invalidFile(message: "No data found in the file.")
        }

        if let error = firstRowResult.error {
            throw error
        }

        // Process headers and determine settings
        let headerSettings = try FastCSV.processHeaders(firstRow: firstRowResult.values, hasHeaders: hasHeaders, customHeaders: headers)
        _headers = headerSettings.headers
        skipFirstRow = headerSettings.skipFirstRow
        headerCount = headerSettings.headerCount
    }

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
        // Process directly with the first row (BOM handling moved elsewhere)
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

    // Keep the removeUTF8BOMIfPresent function for now as we'll use it elsewhere
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

    // MARK: - Public Iterators

    /// Create an iterator over CSV rows as arrays of CSVValue
    /// - Returns: Iterator that yields rows as arrays of CSVValue
    public func makeArrayRows() throws -> CSVArrayIterator {
        let rowIterator = try makeRawIterator()

        return CSVArrayIterator(
            rowIterator: rowIterator,
            headerCount: headerCount,
            skipFirstRow: skipFirstRow
        )
    }

    /// Create an iterator over CSV rows as dictionaries with header keys
    /// - Returns: Iterator that yields rows as dictionaries of String -> CSVValue
    public func makeDictionaryRows() throws -> CSVDictionaryIterator {
        let valueArrayIterator = try makeArrayRows()

        return CSVDictionaryIterator(valueArrayIterator: valueArrayIterator, headers: headers)
    }

    // MARK: - Instance Iterator Methods

    /// Create an iterator over raw CSV rows. Only used internally.
    /// - Returns: Iterator that yields rows as arrays of buffer pointers
    private func makeRawIterator() throws -> CSVRowIterator {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        return CSVRowIterator(fileHandle: fileHandle, skipFirstRow: skipFirstRow, columnCount: headerCount, config: config)
    }
}
