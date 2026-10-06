import Foundation

/// Local Time Machine snapshots, from `tmutil listlocalsnapshots /`.
public enum LocalSnapshots {
    /// The snapshot dates, in the form `tmutil deletelocalsnapshots` takes (2026-10-05-101530).
    public static func parse(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let name = line.trimmingCharacters(in: .whitespaces)
            guard name.hasPrefix("com.apple.TimeMachine."), name.hasSuffix(".local") else { return nil }
            let date = String(name.dropFirst("com.apple.TimeMachine.".count).dropLast(".local".count))
            // The dates end up in an administrator shell command, so only the expected shape passes.
            return date.wholeMatch(of: /\d{4}-\d{2}-\d{2}-\d{6}/) == nil ? nil : date
        }
    }
}

public struct SimulatorDevice: Sendable, Equatable {
    public let name: String
    public let udid: String
    public let runtime: String
    public let isAvailable: Bool
    public let dataBytes: Int64
    public let lastUsed: Date?
}

public struct SimulatorRuntime: Sendable, Equatable {
    public let identifier: String
    public let platform: String
    public let version: String
    public let bytes: Int64
    public let isDeletable: Bool
    public let lastUsed: Date?

    /// "iOS 26.4"
    public var title: String {
        let name = platform
            .replacingOccurrences(of: "com.apple.platform.", with: "")
            .replacingOccurrences(of: "simulator", with: "")
        let known = ["iphone": "iOS", "appletv": "tvOS", "watch": "watchOS", "xr": "visionOS"]
        return "\(known[name] ?? name) \(version)"
    }
}

/// Simulators and simulator runtimes, from `xcrun simctl list -j devices` and
/// `xcrun simctl runtime list -j`.
public enum Simulators {
    public static func parseDevices(_ data: Data) -> [SimulatorDevice] {
        struct List: Decodable {
            let devices: [String: [Device]]
        }
        struct Device: Decodable {
            let name: String
            let udid: String
            let isAvailable: Bool?
            let dataPathSize: Int64?
            let lastUsedAt: String?
        }
        guard let list = try? JSONDecoder().decode(List.self, from: data) else { return [] }
        return list.devices.flatMap { runtime, devices in
            devices.map {
                SimulatorDevice(
                    name: $0.name, udid: $0.udid, runtime: runtime, isAvailable: $0.isAvailable ?? true,
                    dataBytes: $0.dataPathSize ?? 0, lastUsed: $0.lastUsedAt.flatMap(date)
                )
            }
        }
        .sorted { $0.dataBytes > $1.dataBytes }
    }

    public static func parseRuntimes(_ data: Data) -> [SimulatorRuntime] {
        struct Runtime: Decodable {
            let identifier: String
            let platformIdentifier: String?
            let version: String?
            let sizeBytes: Int64?
            let deletable: Bool?
            let lastUsedAt: String?
        }
        guard let list = try? JSONDecoder().decode([String: Runtime].self, from: data) else { return [] }
        return list.values.map {
            SimulatorRuntime(
                identifier: $0.identifier, platform: $0.platformIdentifier ?? "", version: $0.version ?? "",
                bytes: $0.sizeBytes ?? 0, isDeletable: $0.deletable ?? false, lastUsed: $0.lastUsedAt.flatMap(date)
            )
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private static func date(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}

public struct DockerUsage: Sendable, Equatable {
    public let type: String
    public let bytes: Int64
    public let reclaimableBytes: Int64
}

/// Docker's own accounting, from `docker system df --format '{{json .}}'`.
public enum Docker {
    public static func parse(_ output: String) -> [DockerUsage] {
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let row = try? JSONDecoder().decode(DockerRow.self, from: Data(line.utf8)),
                  let size = bytes(row.size), let reclaimable = bytes(row.reclaimable)
            else { return nil }
            return DockerUsage(type: row.type, bytes: size, reclaimableBytes: reclaimable)
        }
    }

    /// Docker's sizes, like "27.43GB" or "938kB (3%)", in decimal units.
    static func bytes(_ text: String) -> Int64? {
        let value = text.split(separator: " ").first.map(String.init) ?? text
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
        for (suffix, multiplier) in units where value.hasSuffix(suffix) {
            guard let number = Double(value.dropLast(suffix.count)) else { return nil }
            return Int64(number * multiplier)
        }
        return nil
    }
}

private struct DockerRow: Decodable {
    let type: String
    let size: String
    let reclaimable: String

    enum CodingKeys: String, CodingKey {
        case type = "Type", size = "Size", reclaimable = "Reclaimable"
    }
}
