import Foundation

extension FastCSV {
    /// Helper class for parsers that provides common byte stream reading and chunk management
    /// Parsers can choose to use this or implement their own state management
    final class ByteChunkReader {
        /// Stream reader to read bytes from
        private let reader: ByteStreamReader
        /// Maximum size of buffer chunks to request when reading
        private let readBufferSize: Int

        /// Whether parsing has finished
        private(set) var isFinished: Bool = false
        /// Current position within the read buffer
        private(set) var currentPosition: Int = 0
        /// Actual size of the current read data chunk
        private(set) var currentReadBufferSize: Int = 0
        /// Pointer to the current byte array being processed
        private(set) var currentBytes: UnsafePointer<UInt8>?
        /// Current buffer of data read from stream
        private var currentReadBuffer: UnsafeMutablePointer<UInt8>?
        /// Previous buffers kept alive because field pointers may reference them
        private var retainedBuffers: [UnsafeMutablePointer<UInt8>] = []
        /// Flag to track if we've already checked for BOM
        private var bomChecked: Bool = false
        /// Tracker to prevent double cleanup
        private let cleanupTracker: CleanupTracker

        init(reader: ByteStreamReader, readBufferSize: Int) {
            self.reader = reader
            self.readBufferSize = readBufferSize
            cleanupTracker = CleanupTracker()
            loadNextChunkIfNeeded()
        }

        deinit {
            cleanup()
        }

        /// Loads the next chunk of data if needed
        func loadNextChunkIfNeeded() {
            if currentPosition >= currentReadBufferSize || currentReadBuffer == nil {
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                    autoreleasepool {
                        self.loadNextChunk()
                    }
                #else
                    loadNextChunk()
                #endif
            }
        }

        /// Internal method to load the next chunk of data
        private func loadNextChunk() {
            // Allocate new buffer and try to read
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readBufferSize)
            let bytesRead = reader.readBytes(into: buffer, maxLength: readBufferSize)

            if bytesRead > 0 {
                // Stream has more data — safe to release the previous buffer
                if let oldBuffer = currentReadBuffer {
                    oldBuffer.deallocate()
                }

                currentReadBuffer = buffer
                currentBytes = UnsafePointer(buffer)
                currentReadBufferSize = bytesRead
                currentPosition = 0

                // Check for UTF-8 BOM in the first chunk only
                if !bomChecked, currentReadBufferSize >= 3 {
                    bomChecked = true

                    // Check for UTF-8 BOM (EF BB BF)
                    if currentBytes![0] == 0xEF,
                       currentBytes![1] == 0xBB,
                       currentBytes![2] == 0xBF
                    {
                        // Skip the BOM by advancing position
                        currentPosition = 3
                    }
                }
            } else {
                // EOF — deallocate the unused new buffer but keep the current
                // buffer alive. The parser may still need to capture a final
                // field from it. Cleanup handles the final deallocation.
                buffer.deallocate()
                isFinished = true
            }
        }

        /// Advances the current position
        func advancePosition() {
            currentPosition += 1
        }

        /// Advances the current position by the specified amount
        func advancePosition(by amount: Int) {
            currentPosition += amount
        }

        /// Sets the current position
        func setPosition(_ position: Int) {
            currentPosition = position
        }

        /// Extends the current buffer when a row spans a chunk boundary.
        /// The old buffer is retained (not freed) so that existing field pointers
        /// into it remain valid. Only the incomplete field's bytes are copied into
        /// the new buffer. Call `releaseRetainedBuffers()` after the row is consumed.
        ///
        /// - Parameter from: The start position of the current incomplete field.
        func extendIntoNextChunk(from preserveStart: Int) {
            guard let oldBuffer = currentReadBuffer else {
                loadNextChunkIfNeeded()
                return
            }

            let preserveCount = currentReadBufferSize - preserveStart

            // Retain the old buffer — completed field pointers reference it
            retainedBuffers.append(oldBuffer)

            // Allocate a new buffer: preserved tail + a full read
            let newBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: preserveCount + readBufferSize)

            // Copy the incomplete field's bytes from the old buffer
            if preserveCount > 0 {
                newBuffer.initialize(from: oldBuffer.advanced(by: preserveStart), count: preserveCount)
            }

            // Read fresh data after the preserved bytes
            let bytesRead = reader.readBytes(into: newBuffer.advanced(by: preserveCount), maxLength: readBufferSize)

            if bytesRead > 0 {
                currentReadBuffer = newBuffer
                currentBytes = UnsafePointer(newBuffer)
                currentReadBufferSize = preserveCount + bytesRead
                currentPosition = preserveCount
            } else if preserveCount > 0 {
                // No more data from stream, but we still have preserved bytes to process
                currentReadBuffer = newBuffer
                currentBytes = UnsafePointer(newBuffer)
                currentReadBufferSize = preserveCount
                currentPosition = preserveCount
            } else {
                // Nothing preserved and nothing read — we're done
                newBuffer.deallocate()
                currentReadBuffer = nil
                isFinished = true
            }
        }

        /// Releases any buffers retained during chunk extensions.
        /// Call this after the parser has finished consuming a row's field pointers.
        func releaseRetainedBuffers() {
            for buffer in retainedBuffers {
                buffer.deallocate()
            }
            retainedBuffers.removeAll(keepingCapacity: true)
        }

        /// Clean up resources
        func cleanup() {
            if !cleanupTracker.hasBeenCleaned {
                reader.cleanup()
                forceFinish()
                cleanupTracker.hasBeenCleaned = true
            }
        }

        /// Force parsing to finish, regardless of remaining data
        private func forceFinish() {
            isFinished = true

            currentBytes = nil

            if let buffer = currentReadBuffer {
                buffer.deallocate()
                currentReadBuffer = nil
            }

            releaseRetainedBuffers()
            currentReadBufferSize = 0
        }
    }
}
