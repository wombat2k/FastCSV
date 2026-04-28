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

/// A ByteStreamReader backed by a POSIX file descriptor.
/// Avoids the FoundationEssentials/Foundation split: FileHandle is not in
/// FoundationEssentials, so we go straight to libc.
final class FileStreamReader: ByteStreamReader {
    private let fd: Int32
    private var didClose = false

    init(url: URL) throws {
        let opened = url.path.withCString { open($0, O_RDONLY) }
        guard opened >= 0 else {
            throw CSVError.invalidFile(message: "Could not open file at \(url.path)")
        }
        fd = opened
    }

    func readBytes(into buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let n = read(fd, buffer, maxLength)
        return n > 0 ? n : 0
    }

    func cleanup() {
        guard !didClose else { return }
        _ = close(fd)
        didClose = true
    }

    deinit { cleanup() }
}

/// A ByteStreamReader that reads from in-memory Data.
/// Used by the fromString/fromData API variants.
final class DataStreamReader: ByteStreamReader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    func readBytes(into buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let remaining = data.count - offset
        let count = min(remaining, maxLength)
        guard count > 0 else { return 0 }
        data.copyBytes(to: buffer, from: offset ..< (offset + count))
        offset += count
        return count
    }

    func cleanup() {
        // No resources to release — Data is managed by ARC
    }
}
