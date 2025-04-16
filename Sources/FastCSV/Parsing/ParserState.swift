import Foundation

extension FastCSV {
    /// Helper class for parsers that provides common file reading and chunk management
    /// Parsers can choose to use this or implement their own state management
    class FileChunkReader {
        /// File handle to read from
        private let fileHandle: FileHandle
        /// Maximum size of buffer chunks to request when reading from file
        private let readBufferSize: Int

        /// Whether parsing has finished
        private(set) var isFinished: Bool = false
        /// Current position within the read buffer
        private(set) var currentPosition: Int = 0
        /// Actual size of the current read data chunk
        private(set) var currentReadBufferSize: Int = 0
        /// Pointer to the current byte array being processed
        private(set) var currentBytes: UnsafePointer<UInt8>?
        /// Current buffer of data read from file
        private var currentReadBuffer: Data?
        /// Flag to track if we've already checked for BOM
        private var bomChecked: Bool = false

        init(fileHandle: FileHandle, readBufferSize: Int) {
            self.fileHandle = fileHandle
            self.readBufferSize = readBufferSize
            loadNextChunkIfNeeded()
        }

        /// Loads the next chunk of data if needed
        func loadNextChunkIfNeeded() {
            if currentPosition >= currentReadBufferSize || currentReadBuffer == nil {
                autoreleasepool {
                    // Release previous chunk data
                    currentReadBuffer = nil

                    do {
                        if let newData = try fileHandle.read(upToCount: readBufferSize), !newData.isEmpty {
                            currentReadBuffer = newData
                            currentReadBufferSize = newData.count
                            currentPosition = 0

                            // Create safe pointer to bytes
                            currentBytes = newData.withUnsafeBytes { pointer in
                                pointer.bindMemory(to: UInt8.self).baseAddress
                            }

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
                            // No more data
                            isFinished = true
                        }
                    } catch {
                        isFinished = true
                    }
                }
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

        /// Clean up resources
        func cleanup() {
            try? fileHandle.close()
            currentReadBuffer = nil
            currentBytes = nil
        }

        /// Force parsing to finish, regardless of remaining data
        func forceFinish() {
            isFinished = true
            // Clean up current data to prevent further processing
            currentReadBuffer = nil
            currentBytes = nil
            currentReadBufferSize = 0
        }
    }
}
