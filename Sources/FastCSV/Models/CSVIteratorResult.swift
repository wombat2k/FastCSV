struct CSVIteratorResult {
    let parsingError: CSVError?

    private enum Storage {
        case direct(UnsafeBufferPointer<UnsafeBufferPointer<UInt8>>, count: Int)
        case array([UnsafeBufferPointer<UInt8>])
    }

    private let storage: Storage

    /// Create a result backed by a pre-allocated buffer (zero-copy, used by fixed-column parsers)
    init(directStorage: UnsafeBufferPointer<UnsafeBufferPointer<UInt8>>, count: Int, parsingError: CSVError?) {
        storage = .direct(directStorage, count: count)
        self.parsingError = parsingError
    }

    /// Create a result backed by an array (used by dynamic-column parser)
    init(fieldPointers: [UnsafeBufferPointer<UInt8>], parsingError: CSVError?) {
        storage = .array(fieldPointers)
        self.parsingError = parsingError
    }

    subscript(index: Int) -> UnsafeBufferPointer<UInt8> {
        precondition(index >= 0 && index < count, "Index out of bounds")

        switch storage {
        case let .direct(buffer, _):
            return buffer[index]
        case let .array(pointers):
            return pointers[index]
        }
    }

    var count: Int {
        switch storage {
        case let .direct(_, count):
            count
        case let .array(pointers):
            pointers.count
        }
    }
}
