import Foundation

/// Protocol for reading bytes from any source
public protocol ByteStreamReader {
    /// Read bytes into the provided buffer
    /// - Parameter buffer: Pointer to the buffer to fill
    /// - Parameter maxLength: Maximum number of bytes to read
    /// - Returns: The number of bytes read, or 0 if end of stream
    func readBytes(into buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int

    /// Clean up any resources associated with the reader
    func cleanup()
}

extension FileHandle: ByteStreamReader {
    // Avoid intermediate Data object for better performance
    public func readBytes(into buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        // Use lower-level read syscall directly when possible
        #if os(macOS) || os(iOS)
            return Darwin.read(fileDescriptor, buffer, maxLength)
        #elseif os(Linux)
            return Glibc.read(fileDescriptor, buffer, maxLength)
        #else
            // Fall back to standard implementation
            let data = readData(ofLength: maxLength)
            if data.count > 0 {
                data.copyBytes(to: buffer, count: data.count)
            }
            return data.count
        #endif
    }

    public func cleanup() {
        do {
            try close()
        } catch {
            // Handle or ignore error
        }
    }
}
