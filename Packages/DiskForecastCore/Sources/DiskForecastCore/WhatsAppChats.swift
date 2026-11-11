import Foundation

/// Which WhatsApp chats hold the most media, so the cleanup list can say where to look in
/// WhatsApp's storage settings. Media sits in `Message/Media/<chat id>/`, and the chat names come
/// from WhatsApp's own database, opened read-only. Nothing is stored or sent anywhere.
enum WhatsAppChats {
    /// "Biggest chats: Family 15 GB, Book club 8 GB, Sam 3 GB", or nil when no chat folder is big
    /// enough to name.
    static func detail(container: String, scan: ScanResult, limit: Int = 3) -> String? {
        let media = container + "/Message/Media"
        let ids = (try? FileManager.default.contentsOfDirectory(atPath: media)) ?? []
        let sizes = Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            scan.allocatedSize(of: media + "/" + id).map { (id, $0) }
        })
        let names = names(database: container + "/ChatStorage.sqlite")
        return ChatMedia.summary(ChatMedia.largest(sizes: sizes, names: names, limit: limit))
    }

    /// Chat id to the name WhatsApp shows. A media folder is named by either id column.
    static func names(database path: String) -> [String: String] {
        let query = "SELECT ZCONTACTJID, ZCONTACTIDENTIFIER, ZPARTNERNAME FROM ZWACHATSESSION WHERE ZPARTNERNAME <> ''"
        var names: [String: String] = [:]
        for row in ReadOnlySQLite.rows(at: path, query: query) {
            guard let name = row[2] else { continue }
            for id in row[0...1].compactMap({ $0 }) { names[id] = name }
        }
        return names
    }
}
