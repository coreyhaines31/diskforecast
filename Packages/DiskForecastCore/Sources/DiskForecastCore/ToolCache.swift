import Foundation

/// A cache that its own tool should clear: moving it to the Trash would free little, break
/// installs that link into it, or leave behind what the tool also tidies. Learned from mattt/plonge.
public struct ToolCache: Sendable, Identifiable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The tool removes only what nothing uses. Nothing has to be downloaded again.
        case prune
        /// The tool removes everything. The next install or build fetches or makes it again.
        case clear
    }

    public let id: String
    /// The program to run, by name.
    public let tool: String
    /// What the list calls the cache: "pnpm store".
    public let name: String
    /// The button's title.
    public let action: String
    /// Arguments that make the tool print where the cache is.
    public let pathArguments: [String]
    public let cleanArguments: [String]
    /// Arguments for a dry run that says how much the cleanup would free, for a tool whose
    /// cleanup reaches past the cache folder.
    public var dryRunArguments: [String]?
    public let kind: Kind
    /// What running it removes and keeps, shown before it runs.
    public let confirmation: String

    /// The command as it's shown: "pnpm store prune".
    public var command: String { ([tool] + cleanArguments).joined(separator: " ") }

    /// "pnpm store · prunes what nothing uses" or "Go modules · clears everything".
    public var kindNote: String {
        switch kind {
        case .prune: "prunes what nothing uses"
        case .clear: "clears everything"
        }
    }

    public static let all: [ToolCache] = [
        ToolCache(
            id: "pnpm-store", tool: "pnpm", name: "pnpm store", action: "Prune the pnpm store",
            pathArguments: ["store", "path"], cleanArguments: ["store", "prune"], kind: .prune,
            confirmation: "Removes packages that no project on this Mac links to any more. Projects share the "
                + "store's files, so what they use stays and nothing needs reinstalling."
        ),
        ToolCache(
            id: "uv-cache", tool: "uv", name: "uv cache", action: "Prune the uv cache",
            pathArguments: ["cache", "dir"], cleanArguments: ["cache", "prune"], kind: .prune,
            confirmation: "Removes cache entries uv no longer uses, like builds for package versions you've "
                + "moved past. What current environments use stays."
        ),
        ToolCache(
            id: "go-modules", tool: "go", name: "Go modules", action: "Clear the Go module cache",
            pathArguments: ["env", "GOMODCACHE"], cleanArguments: ["clean", "-modcache"], kind: .clear,
            confirmation: "Removes every downloaded Go module. Go makes these files read-only, which is why "
                + "its own command is the way to remove them. The next build downloads what it needs again."
        ),
        ToolCache(
            id: "go-build", tool: "go", name: "Go build cache", action: "Clear the Go build cache",
            pathArguments: ["env", "GOCACHE"], cleanArguments: ["clean", "-cache"], kind: .clear,
            confirmation: "Removes everything Go has compiled and kept. The next build of each project "
                + "compiles from scratch."
        ),
        ToolCache(
            id: "homebrew", tool: "brew", name: "Homebrew downloads and old versions", action: "Clean up Homebrew",
            pathArguments: ["--cache"], cleanArguments: ["cleanup", "--prune=all"],
            dryRunArguments: ["cleanup", "--prune=all", "--dry-run"], kind: .clear,
            confirmation: "Removes every download Homebrew kept and the old versions of formulae it left "
                + "installed beside the current ones. What you have installed now stays."
        )
    ]

    /// The folder a tool printed for its cache: the last line that's an absolute path. Tools
    /// sometimes print notices first.
    public static func path(fromOutput output: String) -> String? {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("/") && $0.count > 1 }
    }

    /// What a dry run says the cleanup would free, from a line like Homebrew's "This operation
    /// would free approximately 103.5MB of disk space." Nil when it says nothing of the kind.
    public static func freedBytes(fromDryRun output: String) -> Int64? {
        let pattern = /approximately ([0-9.]+)\s?([KMGT]?)B/
        guard let match = output.firstMatch(of: pattern), let amount = Double(match.1) else { return nil }
        // Homebrew counts in steps of 1024 and writes them as KB, MB, GB.
        let steps = ["": 0, "K": 1, "M": 2, "G": 3, "T": 4][String(match.2)] ?? 0
        return Int64(amount * pow(1024, Double(steps)))
    }

    /// Folders where developer tools get installed, most specific first. An app doesn't get the
    /// PATH a terminal builds, so the usual places are checked directly.
    public static func searchFolders(home: String, nodeVersions: [String] = []) -> [String] {
        // The newest Node that nvm installed, for tools installed with npm.
        let newestNode = nodeVersions
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            .first.map { ["\(home)/.nvm/versions/node/\($0)/bin"] } ?? []
        return [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/local/go/bin",
            "\(home)/.local/bin", "\(home)/Library/pnpm", "\(home)/Library/pnpm/bin",
            "\(home)/.local/share/mise/shims", "\(home)/.cargo/bin", "\(home)/go/bin", "\(home)/.volta/bin"
        ] + newestNode
    }

    /// Where `tool` is installed, from the usual places.
    public static func executable(
        named tool: String, home: String = NSHomeDirectory(),
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> String? {
        let versions = (try? FileManager.default.contentsOfDirectory(atPath: "\(home)/.nvm/versions/node")) ?? []
        return searchFolders(home: home, nodeVersions: versions)
            .map { $0 + "/" + tool }
            .first(where: isExecutable)
    }
}
