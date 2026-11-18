import Foundation

/// The user's own temp folder, $TMPDIR, under /private/var/folders. Apps, scripts, and test runs
/// make folders there and often never remove them.
public enum UserTemp {
    /// With links resolved, so it matches the paths the Trasher checks.
    public static var folder: String { Trasher.resolved(FileManager.default.temporaryDirectory.path) }

    /// Untouched this long, nothing is probably coming back for it.
    public static let idleDays = 3.0
    /// This many idle entries sharing a name's start are said to, so a long list reads as one batch.
    static let batchSize = 10

    /// Entries with more inside than this aren't walked, so they aren't listed.
    static let maximumEntries = 100_000

    /// The newest change to the entry or anything inside it, at any depth. Nil when that can't be
    /// vouched for: something couldn't be read, there's too much to walk, or there's a socket or
    /// pipe inside, which a running program may be listening on though no file is open.
    static func newestChange(in path: String, limit: Int = maximumEntries) -> Date? {
        var newest = 0.0
        var seen = 0
        var stack = [path]
        while let next = stack.popLast() {
            var info = stat()
            guard lstat(next, &info) == 0 else { return nil }
            seen += 1
            guard seen <= limit else { return nil }
            let type = info.st_mode & S_IFMT
            guard type != S_IFSOCK, type != S_IFIFO else { return nil }
            newest = max(newest, Double(info.st_mtimespec.tv_sec))
            if type == S_IFDIR {
                guard let names = try? FileManager.default.contentsOfDirectory(atPath: next) else { return nil }
                stack += names.map { next + "/" + $0 }
            }
        }
        return Date(timeIntervalSince1970: newest)
    }

    /// Whether macOS, not the user's own programs, keeps this entry of the temp folder.
    static func isSystemEntry(_ name: String) -> Bool {
        name.hasPrefix("com.apple.")
    }

    /// The start of a name that tools number or randomize after: "DiskForecastHome-" in
    /// "DiskForecastHome-1A2B…".
    static func batch(of name: String) -> String {
        guard let separator = name.dropFirst().firstIndex(where: { $0 == "-" || $0 == "_" }) else { return name }
        return String(name[...separator])
    }
}

extension CleanupCatalog {
    /// What's directly in the user's temp folder and hasn't changed in a few days, from the
    /// separate scan of `UserTemp.folder`. Only this user's files and folders: never macOS's,
    /// links, or sockets.
    func idleTempFiles() -> [Candidate] {
        guard let root = userTemp?.tree.rootPath else { return [] }
        let cutoff = now.addingTimeInterval(-UserTemp.idleDays * 86_400)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []).filter { name in
            guard !UserTemp.isSystemEntry(name), name != ".DS_Store" else { return false }
            var info = stat()
            guard lstat(root + "/" + name, &info) == 0, info.st_uid == getuid() else { return false }
            let type = info.st_mode & S_IFMT
            // Changed lately at the top means not idle, and too small means not listed: neither needs walking.
            return (type == S_IFDIR || type == S_IFREG)
                && Double(info.st_mtimespec.tv_sec) < cutoff.timeIntervalSince1970
                && (userTemp?.allocatedSize(of: root + "/" + name) ?? 0) >= Self.minimumEntryBytes
        }
        let idle = names.compactMap { name -> (name: String, changed: Date)? in
            guard let changed = UserTemp.newestChange(in: root + "/" + name), changed < cutoff else { return nil }
            return (name, changed)
        }
        let batches = Dictionary(idle.map { (UserTemp.batch(of: $0.name), 1) }, uniquingKeysWith: +)
        return idle.map { entry in
            var detail = "Last changed \(Age.phrase(from: entry.changed, to: now))"
            let batch = UserTemp.batch(of: entry.name)
            if let count = batches[batch], count >= UserTemp.batchSize, batch != entry.name {
                detail += " · 1 of \(count.formatted()) named \(batch)…"
            }
            return Candidate(path: root + "/" + entry.name, detail: detail)
        }
    }
}
