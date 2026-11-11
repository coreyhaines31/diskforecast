import Foundation
import SQLite3

/// Which WhatsApp chats hold the most media, so the cleanup list can say where to look in
/// WhatsApp's storage settings. Media sits in `Message/Media/<chat id>/`, and the chat names come
/// from WhatsApp's own database, opened read-only. Nothing is stored or sent anywhere.
enum WhatsAppChats {
    struct Chat: Equatable {
        let name: String
        let bytes: Int64
    }

    /// "Biggest chats: Family 15 GB, Book club 8 GB, Sam 3 GB", or nil when no chat folder is big
    /// enough to name.
    static func detail(container: String, scan: ScanResult, limit: Int = 3) -> String? {
        let media = container + "/Message/Media"
        let ids = (try? FileManager.default.contentsOfDirectory(atPath: media)) ?? []
        let sizes = Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            scan.allocatedSize(of: media + "/" + id).map { (id, $0) }
        })
        let chats = largest(sizes: sizes, names: names(database: container + "/ChatStorage.sqlite"), limit: limit)
        return summary(chats)
    }

    static func largest(sizes: [String: Int64], names: [String: String], limit: Int) -> [Chat] {
        sizes
            .filter { $0.value >= CleanupCatalog.minimumEntryBytes }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { Chat(name: names[$0.key] ?? "An unnamed chat", bytes: $0.value) }
    }

    static func summary(_ chats: [Chat]) -> String? {
        guard !chats.isEmpty else { return nil }
        let label = chats.count == 1 ? "Biggest chat" : "Biggest chats"
        return label + ": " + chats.map { "\($0.name) \(Bytes.format($0.bytes))" }.joined(separator: ", ")
    }

    /// Chat id to the name WhatsApp shows. A media folder is named by either id column.
    static func names(database path: String) -> [String: String] {
        var connection: OpaquePointer?
        defer { sqlite3_close(connection) }
        guard sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [:] }
        let query = "SELECT ZCONTACTJID, ZCONTACTIDENTIFIER, ZPARTNERNAME FROM ZWACHATSESSION WHERE ZPARTNERNAME <> ''"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(connection, query, -1, &statement, nil) == SQLITE_OK else { return [:] }
        var names: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = text(statement, 2) else { continue }
            for column: Int32 in [0, 1] {
                if let id = text(statement, column) { names[id] = name }
            }
        }
        return names
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
    }
}
