import Foundation
import SQLite3

/// Reads rows from another app's SQLite database without ever writing to it. Any failure (no
/// file, a locked or unfamiliar database) gives no rows, so callers fall back to less detail.
enum ReadOnlySQLite {
    /// Each row's columns as text; NULL and empty values are nil.
    static func rows(at path: String, query: String) -> [[String?]] {
        var connection: OpaquePointer?
        defer { sqlite3_close(connection) }
        guard sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(connection, query, -1, &statement, nil) == SQLITE_OK else { return [] }
        let count = sqlite3_column_count(statement)
        var rows: [[String?]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append((0..<count).map { column in
                sqlite3_column_text(statement, column).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
            })
        }
        return rows
    }
}
