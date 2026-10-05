import Foundation

enum Bytes {
    /// "142 GB" or "8.4 GB", counted the way Finder counts (1 GB = 1,000,000,000 bytes), with a
    /// decimal only where it carries meaning.
    static func format(_ bytes: Int64) -> String {
        let units = ["bytes", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unit = 0
        while abs(value) >= 1_000 && unit < units.count - 1 {
            value /= 1_000
            unit += 1
        }
        if unit == 0 || abs(value) >= 10 {
            return "\(Int(value.rounded())) \(units[unit])"
        }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(units[unit])"
    }
}
