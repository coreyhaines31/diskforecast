import Foundation

extension StorageBreakdown {
    /// Home folders that hold one kind of thing, so a code project inside one is claimed on its
    /// own rather than claiming the whole folder for Developer.
    static let sharedHomeFolders: Set<String> = [
        "Applications", "Desktop", "Documents", "Downloads", "Library", "Movies", "Music", "Pictures", "Public"
    ]

    /// Splits used space using the home folder scan and the Cleanup list built from it.
    /// `applicationsBytes` is the size of /Applications, nil when it wasn't measured. `trashBytes`
    /// is nil until the Trash is measured, which needs Full Disk Access.
    public init(
        home: String, scan: ScanResult, items: [CleanupItem], capacityBytes: Int64, volumeUsedBytes: Int64,
        applicationsBytes: Int64?, trashBytes: Int64?, fullDiskAccess: Bool
    ) {
        let home = Self.normalized(home)
        var unmeasured: [StorageCategory] = []
        var claims: [Claim] = []
        if fullDiskAccess {
            claims.append(Claim(.trash, home + "/.Trash", bytes: trashBytes))
        } else {
            unmeasured.append(.trash)
        }
        if let applicationsBytes {
            claims.append(Claim(.apps, "/Applications", bytes: applicationsBytes))
        } else {
            unmeasured.append(.apps)
        }
        claims.append(Claim(.apps, home + "/Applications"))
        claims += Self.developerClaims(home: home, scan: scan, items: items)
        claims.append(Claim(.caches, home + "/Library/Caches"))
        claims += Self.entries(of: "app-support-caches", in: items).map { Claim(.caches, $0.path) }
        claims.append(Claim(.photos, home + "/Pictures"))
        claims.append(Claim(.movies, home + "/Movies"))
        claims.append(Claim(.music, home + "/Music"))
        claims += ["Documents", "Desktop", "Downloads", "Library/Mobile Documents"]
            .map { Claim(.documents, home + "/" + $0) }
        self.init(
            capacityBytes: capacityBytes, volumeUsedBytes: volumeUsedBytes, claims: claims,
            size: { scan.tree.size(of: $0) }, unmeasured: unmeasured, isComplete: fullDiskAccess
        )
    }

    /// Xcode and simulators, Docker, package caches, then each folder of code projects: a home
    /// folder like ~/code that holds a project with build folders or a worktree is claimed whole;
    /// a project inside Documents or Desktop is claimed on its own.
    static func developerClaims(home: String, scan: ScanResult, items: [CleanupItem]) -> [Claim] {
        var claims = [
            Claim(.developer, home + "/Library/Developer"),
            Claim(.developer, home + "/Library/Containers/com.docker.docker")
        ]
        claims += entries(of: "package-caches", in: items).map { Claim(.developer, $0.path) }
        var projects = scan.artifacts.map(\.projectPath) + scan.worktrees.map(\.path)
        projects += entries(of: "stale-builds", in: items).map { ($0.path as NSString).deletingLastPathComponent }
        projects += entries(of: "active-builds", in: items).map { ($0.path as NSString).deletingLastPathComponent }
        projects += entries(of: "quiet-builds", in: items).map { ($0.path as NSString).deletingLastPathComponent }
        projects += entries(of: "idle-build-output", in: items).map { ($0.path as NSString).deletingLastPathComponent }
        projects += entries(of: "held-builds", in: items).map { ($0.path as NSString).deletingLastPathComponent }
        projects += entries(of: "git-worktrees", in: items).map(\.path)
        projects += entries(of: "finished-worktrees", in: items).map(\.path)
        var folders: [String] = []
        for project in projects where project.hasPrefix(home + "/") {
            let relative = project.dropFirst(home.count + 1)
            guard let top = relative.split(separator: "/").first.map(String.init) else { continue }
            // Library's own developer folders are claimed above; build folders elsewhere in it belong to apps.
            guard top != "Library" else { continue }
            let folder = sharedHomeFolders.contains(top) || top.hasPrefix(".") ? project : home + "/" + top
            if !folders.contains(folder) { folders.append(folder) }
        }
        // Shallowest first, so a folder is claimed before the projects inside it.
        folders.sort { $0.split(separator: "/").count < $1.split(separator: "/").count }
        return claims + folders.map { Claim(.developer, $0) }
    }

    private static func entries(of id: String, in items: [CleanupItem]) -> [CleanupEntry] {
        items.first { $0.id == id }?.entries ?? []
    }
}
