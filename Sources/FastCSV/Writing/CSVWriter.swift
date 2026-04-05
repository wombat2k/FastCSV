import Foundation

/// A CSV writer that supports row-by-row output to a file or string buffer.
///
/// CSVWriter is a class because it owns resources (file handles) and maintains
/// mutable state (column ordering, header emission).
public final class CSVWriter {

    // MARK: - Properties

    private let config: CSVWriterConfig
    private var output: CSVWriteTarget
    private var columnOrder: [String]?
    private var headersWritten: Bool = false
    private var rowCount: Int = 0

    // Cached delimiter characters as strings for quoting logic
    private let fieldDelimiter: String
    private let quoteChar: String
    private let doubledQuote: String

    // MARK: - Initialization

    /// Create a writer that writes to a file path (creates or truncates).
    public convenience init(toPath path: String, config: CSVWriterConfig = CSVWriterConfig()) throws {
        try self.init(toURL: URL(fileURLWithPath: path), config: config)
    }

    /// Create a writer that writes to a file URL.
    public init(toURL url: URL, config: CSVWriterConfig = CSVWriterConfig()) throws {
        let manager = FileManager.default
        if !manager.createFile(atPath: url.path, contents: nil) {
            throw CSVError.writeError(message: "Could not create file at \(url.path)")
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            throw CSVError.writeError(message: "Could not open file for writing at \(url.path)")
        }
        self.config = config
        self.output = FileWriteTarget(fileHandle: handle)
        self.fieldDelimiter = String(UnicodeScalar(config.delimiter.fieldByte))
        self.quoteChar = String(UnicodeScalar(config.delimiter.quoteByte))
        self.doubledQuote = quoteChar + quoteChar
    }

    /// Create a writer backed by an internal string buffer.
    /// Retrieve the result via `toString()`.
    public init(config: CSVWriterConfig = CSVWriterConfig()) {
        self.config = config
        self.output = StringWriteTarget()
        self.fieldDelimiter = String(UnicodeScalar(config.delimiter.fieldByte))
        self.quoteChar = String(UnicodeScalar(config.delimiter.quoteByte))
        self.doubledQuote = quoteChar + quoteChar
    }

    deinit {
        output.close()
    }

    // MARK: - Header Writing

    /// Write column headers. Must be called before any data rows.
    public func writeHeaders(_ headers: [String]) throws {
        guard !headersWritten else {
            throw CSVError.writeError(message: "Headers have already been written")
        }
        guard rowCount == 0 else {
            throw CSVError.writeError(message: "Cannot write headers after data rows")
        }
        columnOrder = headers
        headersWritten = true
        try writeRawRow(headers)
    }

    // MARK: - Row Writing (String Arrays)

    /// Write a row from an array of string values.
    public func writeRow(_ fields: [String]) throws {
        try writeRawRow(fields)
        rowCount += 1
    }

    /// Write multiple rows from arrays of string values.
    public func writeRows(_ rows: [[String]]) throws {
        for row in rows {
            try writeRow(row)
        }
    }

    // MARK: - Row Writing (Encodable)

    /// Write a single Encodable value as a CSV row.
    /// On the first call, CodingKeys define column order and headers are emitted automatically.
    public func writeRow<T: Encodable>(_ value: T) throws {
        let storage = try encodeToStorage(value)

        if columnOrder == nil {
            columnOrder = storage.keys
            if !headersWritten {
                headersWritten = true
                try writeRawRow(storage.keys)
            }
        }

        let fields = columnOrder!.map { key -> String in
            storage.values[key] ?? ""
        }

        try writeRawRow(fields)
        rowCount += 1
    }

    /// Write multiple Encodable values.
    public func writeRows<T: Encodable>(_ values: [T]) throws {
        for value in values {
            try writeRow(value)
        }
    }

    // MARK: - Output

    /// Retrieve the written CSV as a String. Only valid for string-backed writers.
    public func toString() -> String? {
        (output as? StringWriteTarget)?.string
    }

    /// Flush and close the underlying output.
    public func close() {
        output.close()
    }

    // MARK: - Internal

    private func encodeToStorage<T: Encodable>(_ value: T) throws -> EncodedRowStorage {
        let storage = EncodedRowStorage(config: config)
        let encoder = CSVRowEncoder(storage: storage)
        try value.encode(to: encoder)
        return storage
    }

    /// Write a row of string fields, applying RFC 4180 quoting as needed.
    private func writeRawRow(_ fields: [String]) throws {
        var row = ""
        for (index, field) in fields.enumerated() {
            if index > 0 {
                row.append(fieldDelimiter)
            }
            row.append(quoteField(field))
        }
        row.append("\n")
        try output.write(row)
    }

    /// Apply RFC 4180 quoting: fields containing the delimiter, quote char,
    /// or newlines are wrapped in quotes with embedded quotes doubled.
    private func quoteField(_ field: String) -> String {
        let needsQuoting = field.contains(fieldDelimiter)
            || field.contains(quoteChar)
            || field.contains("\n")
            || field.contains("\r")

        if needsQuoting {
            return quoteChar + field.replacing(quoteChar, with: doubledQuote) + quoteChar
        }
        return field
    }
}

// MARK: - Write Targets

private protocol CSVWriteTarget {
    func write(_ string: String) throws
    func close()
}

private final class FileWriteTarget: CSVWriteTarget {
    private let fileHandle: FileHandle

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw CSVError.writeError(message: "Could not encode string as UTF-8")
        }
        fileHandle.write(data)
    }

    func close() {
        try? fileHandle.close()
    }
}

private final class StringWriteTarget: CSVWriteTarget {
    var string: String = ""

    func write(_ str: String) throws {
        string.append(str)
    }

    func close() {}
}
