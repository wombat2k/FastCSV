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

        // Read the first row using a temporary raw iterator and value array iterator
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let rawIterator = CSVIterator(fileHandle: fileHandle, skipFirstRow: false, config: self.config)
        var valueArrayIterator = CSVArrayIterator(rawIterator: rawIterator, headerCount: 0) // No header validation yet
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
        if !customHeaders.isEmpty {
            // If custom headers are provided, use them and validate count
            if customHeaders.count != firstRow.count {
                throw CSVError.invalidCSV(message: "Header count (\(customHeaders.count)) does not match the number of fields in the first row (\(firstRow.count)).")
            }

            // Process empty header values with auto-generated column names
            let processedHeaders = customHeaders.enumerated().map { index, header in
                header.isEmpty ? "column_\(index + 1)" : header // Using 1-based indexing for readability
            }

            // If custom headers are provided AND file has headers,
            // we should skip the first row when reading data
            return (processedHeaders, hasHeaders, processedHeaders.count)
        } else if hasHeaders {
            // If hasHeaders=true, use first row as headers
            let extractedHeaders = try firstRow.map { try $0.getString() ?? "" }

            // Process empty header values with auto-generated column names
            let processedHeaders = extractedHeaders.enumerated().map { index, header in
                header.isEmpty ? "column_\(index + 1)" : header // Using 1-based indexing for readability
            }

            return (processedHeaders, true, processedHeaders.count)
        } else {
            // No headers in file or provided, generate auto-numbered columns
            let generatedHeaders = (0 ..< firstRow.count).map { "column_\($0 + 1)" }
            return (generatedHeaders, false, firstRow.count)
        }
    }

    // MARK: - Instance Iterator Methods

    /// Create an iterator over raw CSV rows
    /// - Returns: Iterator that yields rows as arrays of buffer pointers
    func makeRawIterator() throws -> CSVIterator {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        return CSVIterator(fileHandle: fileHandle, skipFirstRow: skipFirstRow, columnCount: headerCount, config: config)
    }

    /// Create an iterator over CSV rows as arrays of CSVValue
    /// - Returns: Iterator that yields rows as arrays of CSVValue
    public func makeValueArrayIterator() throws -> CSVArrayIterator {
        do {
            let rawIterator = try makeRawIterator()

            return CSVArrayIterator(
                rawIterator: rawIterator,
                headerCount: headerCount
            )
        } catch {
            // If raw iterator creation fails, propagate the error
            throw error
        }
    }

    /// Create an iterator over CSV rows as dictionaries with header keys
    /// - Returns: Iterator that yields rows as dictionaries of String -> CSVValue
    public func makeValueDictionaryIterator() throws -> CSVDictionaryIterator {
        do {
            let valueArrayIterator = try makeValueArrayIterator()
            return CSVDictionaryIterator(valueArrayIterator: valueArrayIterator, headers: headers)
        } catch {
            // If iterator creation fails, propagate the error
            throw error
        }
    }
}
