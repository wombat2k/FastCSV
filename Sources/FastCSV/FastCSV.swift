#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

/// High-performance streaming CSV parser that returns rows on demand
public enum FastCSV {
    // MARK: - Header Processing

    /// Process header information based on first row and configuration
    static func processHeaders(firstRow: [CSVValue], hasHeaders: Bool, customHeaders: [String]) throws ->
        (headers: [String], skipFirstRow: Bool)
    {
        if !customHeaders.isEmpty {
            if customHeaders.count != firstRow.count {
                throw CSVError.invalidCSV(message: "Header count (\(customHeaders.count)) does not match the number of fields in the first row (\(firstRow.count)).")
            }

            let processedHeaders = processEmptyHeaders(headers: customHeaders)

            // If custom headers are provided AND file has headers,
            // we should skip the first row when reading data
            return (processedHeaders, hasHeaders)
        } else if hasHeaders {
            let extractedHeaders = try firstRow.map { try $0.stringIfPresent() ?? "" }

            let processedHeaders = processEmptyHeaders(headers: extractedHeaders)

            return (processedHeaders, true)
        } else {
            let emptyHeaders = Array(repeating: "", count: firstRow.count)
            let processedHeaders = processEmptyHeaders(headers: emptyHeaders)
            return (processedHeaders, false)
        }
    }

    /// Removes UTF-8 BOM from the first field of a row if present
    static func removeUTF8BOMIfPresent(fromRow row: [CSVValue]) -> [CSVValue] {
        var result = row

        if !result.isEmpty,
           let firstValue = try? result[0].stringIfPresent(),
           firstValue.hasPrefix("\u{FEFF}")
        {
            let cleanedField = firstValue.dropFirst(1)
            result[0] = CSVValue(bytes: Array(cleanedField.utf8))
        }

        return result
    }

    /// Process headers by replacing empty values with auto-generated column names
    private static func processEmptyHeaders(headers: [String]) -> [String] {
        headers.enumerated().map { index, header in
            header.isEmpty ? "column_\(index + 1)" : header
        }
    }

    // MARK: - File Input

    /// Create an iterator over CSV rows as arrays of CSVValue
    public static func makeArrayRows(fromPath path: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        try makeArrayRows(fromURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Create an iterator over CSV rows as arrays of CSVValue
    public static func makeArrayRows(fromURL url: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        let reader = try FileStreamReader(url: url)
        return try CSVArrayIterator(
            reader: reader,
            hasHeaders: hasHeaders,
            customHeaders: headers,
            config: config ?? CSVParserConfig(),
        )
    }

    /// Create an iterator over CSV rows as dictionaries with header keys
    public static func makeDictionaryRows(fromPath path: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        try makeDictionaryRows(fromURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Create an iterator over CSV rows as dictionaries with header keys
    public static func makeDictionaryRows(fromURL url: URL, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        let iter = try makeArrayRows(fromURL: url, hasHeaders: hasHeaders, headers: headers, config: config)
        return CSVDictionaryIterator(valueArrayIterator: iter, headers: iter.headers)
    }

    // MARK: - Decodable Rows

    /// Create a lazy sequence that decodes CSV rows into Decodable structs.
    public static func makeRows<T: Decodable>(
        _ type: T.Type,
        fromPath path: String,
        hasHeaders: Bool = true,
        headers: [String] = [],
        columnMapping: [String: String] = [:],
        config: CSVParserConfig? = nil,
    ) throws -> CSVDecodableIterator<T> {
        try makeRows(type, fromURL: URL(fileURLWithPath: path), hasHeaders: hasHeaders, headers: headers, columnMapping: columnMapping, config: config)
    }

    /// Create a lazy sequence that decodes CSV rows into Decodable structs.
    public static func makeRows<T: Decodable>(
        _: T.Type,
        fromURL url: URL,
        hasHeaders: Bool = true,
        headers: [String] = [],
        columnMapping: [String: String] = [:],
        config: CSVParserConfig? = nil,
    ) throws -> CSVDecodableIterator<T> {
        let iter = try makeArrayRows(fromURL: url, hasHeaders: hasHeaders, headers: headers, config: config)
        return CSVDecodableIterator<T>(
            valueArrayIterator: iter,
            headers: iter.headers,
            quoteChar: iter.quoteChar,
            dateStrategy: config?.dateStrategy ?? .iso8601Date,
            columnMapping: columnMapping,
        )
    }

    // MARK: - Data Input

    /// Create an iterator over CSV rows as arrays of CSVValue from in-memory Data.
    public static func makeArrayRows(fromData data: Data, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        try CSVArrayIterator(
            reader: DataStreamReader(data: data),
            hasHeaders: hasHeaders,
            customHeaders: headers,
            config: config ?? CSVParserConfig(),
        )
    }

    /// Create an iterator over CSV rows as dictionaries from in-memory Data.
    public static func makeDictionaryRows(fromData data: Data, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        let iter = try makeArrayRows(fromData: data, hasHeaders: hasHeaders, headers: headers, config: config)
        return CSVDictionaryIterator(valueArrayIterator: iter, headers: iter.headers)
    }

    /// Create a lazy sequence that decodes CSV rows into Decodable structs from in-memory Data.
    public static func makeRows<T: Decodable>(
        _: T.Type,
        fromData data: Data,
        hasHeaders: Bool = true,
        headers: [String] = [],
        columnMapping: [String: String] = [:],
        config: CSVParserConfig? = nil,
    ) throws -> CSVDecodableIterator<T> {
        let iter = try makeArrayRows(fromData: data, hasHeaders: hasHeaders, headers: headers, config: config)
        return CSVDecodableIterator<T>(
            valueArrayIterator: iter,
            headers: iter.headers,
            quoteChar: iter.quoteChar,
            dateStrategy: config?.dateStrategy ?? .iso8601Date,
            columnMapping: columnMapping,
        )
    }

    // MARK: - String Input

    /// Create an iterator over CSV rows as arrays of CSVValue from a CSV string.
    public static func makeArrayRows(fromString string: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVArrayIterator {
        try makeArrayRows(fromData: Data(string.utf8), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Create an iterator over CSV rows as dictionaries from a CSV string.
    public static func makeDictionaryRows(fromString string: String, hasHeaders: Bool = true, headers: [String] = [], config: CSVParserConfig? = nil) throws -> CSVDictionaryIterator {
        try makeDictionaryRows(fromData: Data(string.utf8), hasHeaders: hasHeaders, headers: headers, config: config)
    }

    /// Create a lazy sequence that decodes CSV rows into Decodable structs from a CSV string.
    public static func makeRows<T: Decodable>(
        _ type: T.Type,
        fromString string: String,
        hasHeaders: Bool = true,
        headers: [String] = [],
        columnMapping: [String: String] = [:],
        config: CSVParserConfig? = nil,
    ) throws -> CSVDecodableIterator<T> {
        try makeRows(type, fromData: Data(string.utf8), hasHeaders: hasHeaders, headers: headers, columnMapping: columnMapping, config: config)
    }

    // MARK: - Writing (Encodable → File)

    /// Write Encodable rows to a file path as CSV.
    /// Headers are derived automatically from CodingKeys.
    public static func writeRows(
        _ rows: [some Encodable],
        toPath path: String,
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws {
        try writeRows(rows, toURL: URL(fileURLWithPath: path), config: config)
    }

    /// Write Encodable rows to a file URL as CSV.
    /// Headers are derived automatically from CodingKeys.
    public static func writeRows(
        _ rows: [some Encodable],
        toURL url: URL,
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws {
        let writer = try CSVWriter(toURL: url, config: config)
        defer { writer.close() }
        try writer.writeRows(rows)
    }

    /// Write Encodable rows to a CSV string.
    /// Headers are derived automatically from CodingKeys.
    public static func writeString(
        _ rows: [some Encodable],
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws -> String {
        let writer = CSVWriter(config: config)
        try writer.writeRows(rows)
        guard let result = writer.toString() else {
            throw CSVError.writeError(message: "Failed to produce CSV string output.")
        }
        return result
    }

    // MARK: - Writing (String Arrays → File)

    /// Write string array rows to a file path as CSV.
    public static func writeRows(
        _ rows: [[String]],
        headers: [String]? = nil,
        toPath path: String,
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws {
        try writeRows(rows, headers: headers, toURL: URL(fileURLWithPath: path), config: config)
    }

    /// Write string array rows to a file URL as CSV.
    public static func writeRows(
        _ rows: [[String]],
        headers: [String]? = nil,
        toURL url: URL,
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws {
        let writer = try CSVWriter(toURL: url, config: config)
        defer { writer.close() }
        if let headers {
            try writer.writeHeaders(headers)
        }
        try writer.writeRows(rows)
    }

    /// Write string array rows to a CSV string.
    public static func writeString(
        _ rows: [[String]],
        headers: [String]? = nil,
        config: CSVWriterConfig = CSVWriterConfig(),
    ) throws -> String {
        let writer = CSVWriter(config: config)
        if let headers {
            try writer.writeHeaders(headers)
        }
        try writer.writeRows(rows)
        guard let result = writer.toString() else {
            throw CSVError.writeError(message: "Failed to produce CSV string output.")
        }
        return result
    }
}
