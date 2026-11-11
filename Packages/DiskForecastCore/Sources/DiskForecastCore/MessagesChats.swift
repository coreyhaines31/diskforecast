import Foundation

/// Which Messages conversations hold the most attachments. Each attachment sits in its own folder
/// under `Attachments`, and `chat.db` (opened read-only) says which conversation it came from.
/// Sizes come from the scan, so attachments already offloaded to iCloud don't count.
enum MessagesChats {
    static func detail(messages: String, scan: ScanResult, limit: Int = 3) -> String? {
        let query = """
            SELECT c.ROWID, COALESCE(NULLIF(c.display_name, ''), c.chat_identifier), a.filename
            FROM attachment a
            JOIN message_attachment_join ma ON ma.attachment_id = a.ROWID
            JOIN chat_message_join cm ON cm.message_id = ma.message_id
            JOIN chat c ON c.ROWID = cm.chat_id
            """
        var names: [String: String] = [:]
        var folders: [String: Set<String>] = [:]
        for row in ReadOnlySQLite.rows(at: messages + "/chat.db", query: query) {
            guard let chat = row[0], let file = row[2] else { continue }
            if let name = row[1] { names[chat] = name }
            folders[chat, default: []].insert(folder(of: file, messages: messages))
        }
        let sizes = folders.mapValues { $0.reduce(0) { $0 + (scan.allocatedSize(of: $1) ?? 0) } }
        return ChatMedia.summary(ChatMedia.largest(sizes: sizes, names: names, limit: limit))
    }

    /// The attachment's own folder. Messages stores paths like
    /// `~/Library/Messages/Attachments/ab/11/<id>/IMG_0001.heic`.
    static func folder(of file: String, messages: String) -> String {
        let prefix = "~/Library/Messages/"
        let path = file.hasPrefix(prefix) ? messages + "/" + file.dropFirst(prefix.count) : file
        return (path as NSString).deletingLastPathComponent
    }
}
