struct CSVIteratorResult {
    public let fieldPointers: [UnsafeBufferPointer<UInt8>]
    public let parsingError: CSVError?
    // Add an underlying storage property to avoid temporary array creation
    private let fixedStorage: UnsafeBufferPointer<UnsafeBufferPointer<UInt8>>?
    private let fieldCount: Int

    // Add a constructor that allows direct passing of existing arrays for zero-copy field pointers
    init(fieldPointers: [UnsafeBufferPointer<UInt8>], parsingError: CSVError?) {
        self.fieldPointers = fieldPointers
        self.parsingError = parsingError
        fixedStorage = nil
        fieldCount = fieldPointers.count
    }

    // Optimized constructor that avoids array creation by keeping a reference to the buffer
    init(directStorage: UnsafeBufferPointer<UnsafeBufferPointer<UInt8>>, count: Int, parsingError: CSVError?) {
        fixedStorage = directStorage
        fieldCount = count
        // Create a custom array facade that accesses the underlying buffer directly
        fieldPointers = []
        self.parsingError = parsingError
    }

    // Add subscript accessor to support direct access without array copying
    subscript(index: Int) -> UnsafeBufferPointer<UInt8> {
        precondition(index >= 0 && index < fieldCount, "Index out of bounds")

        if let storage = fixedStorage {
            return storage[index]
        }

        return fieldPointers[index]
    }

    // Add count property to support looping without array copying
    var count: Int {
        return fieldCount
    }
}
