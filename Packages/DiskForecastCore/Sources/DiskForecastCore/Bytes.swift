import Foundation

public enum Bytes {
    /// "142 GB" or "8.4 GB", counted the way Finder counts (1 GB = 1,000,000,000 bytes), with a
    /// decimal only where it carries meaning.
    public static func format(_ bytes: Int64) -> String {
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

    /// Reads a size like "5GB", "500MB" or "1.5T", counted the same way. Nil without a unit, or
    /// for anything that isn't more than zero.
    public static func parse(_ text: String) -> Int64? {
        let multipliers: [String: Double] = [
            "B": 1, "K": 1e3, "KB": 1e3, "M": 1e6, "MB": 1e6, "G": 1e9, "GB": 1e9, "T": 1e12, "TB": 1e12
        ]
        let upper = text.uppercased()
        guard let unitStart = upper.firstIndex(where: \.isLetter),
              let multiplier = multipliers[String(upper[unitStart...])],
              let number = Double(upper[..<unitStart]),
              number > 0, number * multiplier < 1e18
        else { return nil }
        return Int64((number * multiplier).rounded())
    }
}
