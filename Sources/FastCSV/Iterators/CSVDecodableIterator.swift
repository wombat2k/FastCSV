import Foundation

public extension FastCSV {
    /// Lazy sequence that decodes CSV rows into Decodable structs on each iteration.
    /// Wraps CSVArrayIterator with a column index map for O(1) header-to-index lookup.
    /// Only columns matching the Decodable type's CodingKeys are decoded.
    /// - Note: This iterator is not thread-safe. It should only be used in a single-threaded context.
    /// - Note: This iterator will automatically clean up resources after the last row is processed,
    ///   but the caller is responsible for calling cleanup() if they stop iterating early.
    struct CSVDecodableIterator<T: Decodable>: IteratorProtocol, Sequence {
        public typealias Element = Result<T, any Error>

        private var valueArrayIterator: CSVArrayIterator
        private let columnIndexMap: [String: Int]
        private let quoteChar: UInt8

        init(valueArrayIterator: CSVArrayIterator, headers: [String], quoteChar: UInt8) {
            self.valueArrayIterator = valueArrayIterator

            var map = [String: Int](minimumCapacity: headers.count)
            for (index, header) in headers.enumerated() {
                map[header] = index
            }
            self.columnIndexMap = map
            self.quoteChar = quoteChar
        }

        /// Returns the next decoded row, or nil when iteration is complete.
        public mutating func next() -> Result<T, any Error>? {
            guard let arrayResult = valueArrayIterator.next() else {
                return nil
            }

            if let error = arrayResult.error {
                return .failure(error)
            }

            do {
                let decoder = CSVRowDecoder(
                    values: arrayResult.values,
                    columnIndexMap: columnIndexMap,
                    quoteChar: quoteChar
                )
                let decoded = try T(from: decoder)
                return .success(decoded)
            } catch {
                return .failure(error)
            }
        }

        /// Cleans up resources used by this iterator and the underlying iterators.
        /// Call this method when not iterating through all rows.
        public mutating func cleanup() {
            valueArrayIterator.cleanup()
        }

        /// Process all rows with a throwing callback. Automatically cleans up resources.
        /// This is the primary API for Decodable iteration with error propagation.
        /// - Parameter callback: Function to process each decoded row
        /// - Throws: The first decoding or parsing error encountered
        public mutating func forEach(_ callback: (T) throws -> Void) throws {
            defer { cleanup() }

            while let result = next() {
                let value = try result.get()
                try callback(value)
            }
        }
    }
}
