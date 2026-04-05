@testable import FastCSV
import Foundation
import Testing

struct CleanupTests {
    @Test
    func `Double cleanup succeeds`() throws {
        let headers = TestUtils.createHeaders(count: 10)
        let values = TestUtils.createValues(rows: 10, columns: 10)
        let fileURL = try TestUtils.createTemporaryCSVFile(headers: headers, rows: values)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        var rows = try FastCSV.makeArrayRows(fromURL: fileURL)

        // First read
        for _ in rows {}

        // First cleanup
        rows.cleanup()

        // Second cleanup
        rows.cleanup()

        #expect(Bool(true), "Double cleanup should succeed")
    }
}
