import Darwin
@testable import DiskForecastCore
import Foundation
import SQLite3
import Testing

struct WhatsAppChatsTests {
    let container: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "WhatsApp-\(UUID().uuidString)")
        container = URL(filePath: Trasher.resolved(base.path))
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    private func media(_ chat: String, bytes: Int) throws {
        let url = container.appending(path: "Message/Media/\(chat)/0/a.jpg")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
        try data.write(to: url)
    }

    /// The columns WhatsApp's ChatStorage.sqlite has, filled with the given chats.
    private func database(_ rows: [[String?]]) throws {
        var connection: OpaquePointer?
        defer { sqlite3_close(connection) }
        let path = container.appending(path: "ChatStorage.sqlite").path
        try #require(sqlite3_open(path, &connection) == SQLITE_OK)
        let schema = "CREATE TABLE ZWACHATSESSION (ZCONTACTJID TEXT, ZCONTACTIDENTIFIER TEXT, ZPARTNERNAME TEXT)"
        sqlite3_exec(connection, schema, nil, nil, nil)
        for row in rows {
            let values = row.map { $0.map { "'\($0)'" } ?? "NULL" }
            let insert = "INSERT INTO ZWACHATSESSION VALUES (\(values.joined(separator: ",")))"
            sqlite3_exec(connection, insert, nil, nil, nil)
        }
    }

    private func detail() async -> String? {
        let scan = await DiskScanner(options: .init(root: container, diskImageThreshold: 1_000_000_000)).scan()
        return WhatsAppChats.detail(container: container.path, scan: scan)
    }

    @Test func namesTheBiggestChatsLargestFirst() async throws {
        try database([
            ["111@g.us", nil, "Book club"],
            ["222@s.whatsapp.net", nil, "Sam"],
            ["333@g.us", nil, "Family"],
            ["444@g.us", nil, "Neighbors"]
        ])
        try media("111@g.us", bytes: 3_000_000)
        try media("222@s.whatsapp.net", bytes: 2_000_000)
        try media("333@g.us", bytes: 5_000_000)
        try media("444@g.us", bytes: 1_200_000)
        let detail = try #require(await detail())
        #expect(detail.hasPrefix("Biggest chats: Family "))
        #expect(detail.contains(", Book club ") && detail.contains(", Sam "))
        #expect(!detail.contains("Neighbors"))
    }

    @Test func matchesAFolderNamedByTheOtherIdentifier() async throws {
        try database([["555@s.whatsapp.net", "999@lid", "Alex"]])
        try media("999@lid", bytes: 2_000_000)
        #expect(await detail()?.hasPrefix("Biggest chat: Alex ") == true)
    }

    @Test func callsAChatWithNoNameUnnamed() async throws {
        try database([["111@g.us", nil, nil]])
        try media("111@g.us", bytes: 2_000_000)
        #expect(await detail()?.hasPrefix("Biggest chat: An unnamed chat ") == true)
    }

    @Test func skipsChatsWithLittleMedia() async throws {
        try database([["111@g.us", nil, "Book club"]])
        try media("111@g.us", bytes: 10_000)
        #expect(await detail() == nil)
    }

    @Test func stillSizesChatsWithoutTheDatabase() async throws {
        try media("111@g.us", bytes: 2_000_000)
        #expect(await detail()?.hasPrefix("Biggest chat: An unnamed chat ") == true)
    }
}
