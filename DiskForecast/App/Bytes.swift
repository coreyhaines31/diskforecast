import Foundation

enum Bytes {
    /// "142 GB", counted the way Finder counts (1 GB = 1,000,000,000 bytes).
    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
