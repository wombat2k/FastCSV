#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

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
        let fd = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_TRUNC, 0o644) }
        guard fd >= 0 else {
            throw CSVError.writeError(message: "Could not open file for writing at \(url.path)")
        }
        self.config = config
        output = FileWriteTarget(fd: fd)
        fieldDelimiter = String(UnicodeScalar(config.delimiter.fieldByte))
        quoteChar = String(UnicodeScalar(config.delimiter.quoteByte))
        doubledQuote = quoteChar + quoteChar
    }

    /// Create a writer backed by an internal string buffer.
    /// Retrieve the result via `toString()`.
    public init(config: CSVWriterConfig = CSVWriterConfig()) {
        self.config = config
        output = StringWriteTarget()
        fieldDelimiter = String(UnicodeScalar(config.delimiter.fieldByte))
        quoteChar = String(UnicodeScalar(config.delimiter.quoteByte))
        doubledQuote = quoteChar + quoteChar
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
    public func writeRow(_ value: some Encodable) throws {
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
    public func writeRows(_ values: [some Encodable]) throws {
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

    private func encodeToStorage(_ value: some Encodable) throws -> EncodedRowStorage {
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
    private let fd: Int32
    private var didClose = false

    init(fd: Int32) {
        self.fd = fd
    }

    func write(_ string: String) throws {
        let bytes = Array(string.utf8)
        try bytes.withUnsafeBufferPointer { buf in
            guard var ptr = buf.baseAddress else { return }
            var remaining = buf.count
            while remaining > 0 {
                let n = posixWrite(fd, ptr, remaining)
                if n < 0 {
                    throw CSVError.writeError(message: "Write to file descriptor failed")
                }
                remaining -= n
                ptr = ptr.advanced(by: n)
            }
        }
    }

    func close() {
        guard !didClose else { return }
        _ = posixClose(fd)
        didClose = true
    }
}

@inline(__always)
private func posixWrite(_ fd: Int32, _ buf: UnsafePointer<UInt8>, _ n: Int) -> Int {
    #if canImport(Darwin)
        return Darwin.write(fd, buf, n)
    #elseif canImport(Glibc)
        return Glibc.write(fd, buf, n)
    #elseif canImport(Musl)
        return Musl.write(fd, buf, n)
    #else
        return -1
    #endif
}

@inline(__always)
private func posixClose(_ fd: Int32) -> Int32 {
    #if canImport(Darwin)
        return Darwin.close(fd)
    #elseif canImport(Glibc)
        return Glibc.close(fd)
    #elseif canImport(Musl)
        return Musl.close(fd)
    #else
        return -1
    #endif
}

private final class StringWriteTarget: CSVWriteTarget {
    var string: String = ""

    func write(_ str: String) throws {
        string.append(str)
    }

    func close() {}
}
