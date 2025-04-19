@testable import FastCSV
import Foundation
import Testing

@Suite("FastCSV Tests")
struct name {
    @Test("Double cleanup succeeds")
    func doubleCleanupSucceeds() async throws {
        let headers = TestUtils.createHeaders(count: 10)
        let values = TestUtils.createValues(rows: 10, columns: 10)
        let fileURL = try TestUtils.createTemporaryCSVFile(headers: headers, rows: values)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let parser = try FastCSV(fileURL: fileURL)
        var iterator = try parser.makeArrayIterator()

        // First read
        for _ in iterator {}

        // First cleanup
        iterator.cleanup()

        // Second cleanup
        iterator.cleanup()

        #expect(Bool(true), "Double cleanup should succeed")
    }
}
