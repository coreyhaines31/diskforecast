import Foundation

/// The chats holding the most media in a messaging app, as a cleanup entry's detail line.
enum ChatMedia {
    struct Chat: Equatable {
        let name: String
        let bytes: Int64
    }

    static let unnamed = "An unnamed chat"

    static func largest(sizes: [String: Int64], names: [String: String], limit: Int) -> [Chat] {
        sizes
            .filter { $0.value >= CleanupCatalog.minimumEntryBytes }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { Chat(name: names[$0.key] ?? unnamed, bytes: $0.value) }
    }

    /// "Biggest chats: Family 15 GB, Book club 8 GB, Sam 3 GB", or nil when there are none.
    static func summary(_ chats: [Chat]) -> String? {
        guard !chats.isEmpty else { return nil }
        let label = chats.count == 1 ? "Biggest chat" : "Biggest chats"
        return label + ": " + chats.map { "\($0.name) \(Bytes.format($0.bytes))" }.joined(separator: ", ")
    }
}
