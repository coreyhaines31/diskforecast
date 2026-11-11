import Darwin
@testable import DiskForecastCore
import Foundation
import SQLite3
import Testing

struct MessagesChatsTests {
    let messages: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "Messages-\(UUID().uuidString)")
        messages = URL(filePath: Trasher.resolved(base.path))
        try FileManager.default.createDirectory(at: messages, withIntermediateDirectories: true)
    }

    struct Chat {
        let id: Int
        let name: String?
        let identifier: String
    }

    /// A chat.db with the tables Messages uses to tie attachments to conversations.
    private func database(chats: [Chat], attachments: [(chat: Int, file: String)]) throws {
        var connection: OpaquePointer?
        defer { sqlite3_close(connection) }
        try #require(sqlite3_open(messages.appending(path: "chat.db").path, &connection) == SQLITE_OK)
        var sql = """
            CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, chat_identifier TEXT, display_name TEXT);
            CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, filename TEXT);
            CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
            CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
            """
        for chat in chats {
            let name = chat.name.map { "'\($0)'" } ?? "NULL"
            sql += "INSERT INTO chat VALUES (\(chat.id), '\(chat.identifier)', \(name));"
        }
        for (index, attachment) in attachments.enumerated() {
            sql += "INSERT INTO attachment VALUES (\(index), '\(attachment.file)');"
            sql += "INSERT INTO message_attachment_join VALUES (\(index), \(index));"
            sql += "INSERT INTO chat_message_join VALUES (\(attachment.chat), \(index));"
        }
        try #require(sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK)
    }

    /// Writes the file and returns the path Messages would record for it.
    private func attachment(_ relative: String, bytes: Int) throws -> String {
        let url = messages.appending(path: "Attachments/" + relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
        try data.write(to: url)
        return "~/Library/Messages/Attachments/" + relative
    }

    private func detail() async -> String? {
        let scan = await DiskScanner(options: .init(root: messages, diskImageThreshold: 1_000_000_000)).scan()
        return MessagesChats.detail(messages: messages.path, scan: scan)
    }

    @Test func namesTheConversationsWithTheMostAttachments() async throws {
        let video = try attachment("ab/01/A1/video.mov", bytes: 3_000_000)
        let photo = try attachment("ab/02/A2/photo.heic", bytes: 1_500_000)
        let other = try attachment("cd/01/B1/scan.pdf", bytes: 2_000_000)
        try database(
            chats: [
                Chat(id: 1, name: "Family", identifier: "chat123"),
                Chat(id: 2, name: nil, identifier: "+16195550100")
            ],
            attachments: [(1, video), (1, photo), (2, other)]
        )
        let detail = try #require(await detail())
        #expect(detail.hasPrefix("Biggest chats: Family "))
        // A conversation with no name goes by its phone number or email.
        #expect(detail.contains(", +16195550100 "))
    }

    @Test func skipsAttachmentsNoLongerOnThisMac() async throws {
        let gone = "~/Library/Messages/Attachments/ab/01/A1/gone.mov"
        try database(chats: [Chat(id: 1, name: "Family", identifier: "chat123")], attachments: [(1, gone)])
        #expect(await detail() == nil)
    }

    @Test func givesNoDetailWithoutTheDatabase() async throws {
        _ = try attachment("ab/01/A1/video.mov", bytes: 3_000_000)
        #expect(await detail() == nil)
    }

    @Test func findsTheAttachmentsOwnFolder() {
        let file = "~/Library/Messages/Attachments/ab/01/A1/x.jpg"
        #expect(MessagesChats.folder(of: file, messages: "/Users/me/Library/Messages")
            == "/Users/me/Library/Messages/Attachments/ab/01/A1")
    }
}
