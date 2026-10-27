import Foundation

/// Moves things to the Trash, or deletes them when asked, and only things it's safe to remove:
/// inside the home folder or a Claude Code session's temp files, never the home folder or one of
/// its standard folders, and never through a link that leads out.
public struct Trasher: Sendable {
    public enum Refusal: Error, Equatable, CustomStringConvertible {
        case outsideHome
        case protectedFolder
        case missing

        public var description: String {
            switch self {
            case .outsideHome: "It's outside your home folder."
            case .protectedFolder: "It's one of your Mac's standard folders."
            case .missing: "It's no longer there."
            }
        }
    }

    public struct Report: Sendable {
        public var moved: [String] = []
        public var movedBytes: Int64 = 0
        public var failed: [(path: String, reason: String)] = []
        /// Where each moved path ended up in the Trash, for putting it back.
        public var inTrash: [String: String] = [:]
        /// What each moved path held.
        public var movedSizes: [String: Int64] = [:]
        /// A move failed because the disk had no room left, which even the Trash needs.
        public var diskFull = false
        /// Deleted outright rather than moved to the Trash, so there's nothing to put back.
        public var deleted = false
        /// Reasons that already name what they're about, so they're listed without folder names.
        var namedReasons: Set<String> = []

        /// One line per reason, naming up to three folders by their parent and name, since many
        /// failures share a reason and a folder name like node_modules.
        public func failureLines(limit: Int = 5) -> [String] {
            var order: [String] = []
            var paths: [String: [String]] = [:]
            for failure in failed {
                if paths[failure.reason] == nil { order.append(failure.reason) }
                paths[failure.reason, default: []].append(failure.path)
            }
            return order.prefix(limit).map { reason in
                let all = paths[reason] ?? []
                let names = all.prefix(3).map(Self.label).joined(separator: ", ")
                let more = all.count > 3 ? " and \(all.count - 3) more" : ""
                return namedReasons.contains(reason) ? "• \(reason)" : "• \(names)\(more): \(reason)"
            }
        }

        static func label(_ path: String) -> String {
            let url = URL(filePath: path)
            let parent = url.deletingLastPathComponent().lastPathComponent
            return parent.isEmpty || parent == "/" ? url.lastPathComponent : parent + "/" + url.lastPathComponent
        }
    }

    static let protectedNames: Set<String> = [
        "Library", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public",
        "Applications", ".Trash"
    ]

    public let home: String
    /// Claude Code's temp folder. The one place outside home it moves things from, and only
    /// whole sessions or what's inside them.
    let agentScratch: String

    public init(home: String, agentScratch: String = AgentScratch.folder) {
        self.home = Self.resolved(home)
        self.agentScratch = Self.resolved(agentScratch)
    }

    /// Why a path can't go to the Trash, or nil when it can.
    public func refusal(for path: String) -> Refusal? {
        let parent = Self.resolved((path as NSString).deletingLastPathComponent)
        let name = (path as NSString).lastPathComponent
        guard !name.isEmpty, name != ".", name != ".." else { return .protectedFolder }
        let full = parent + "/" + name
        guard full.hasPrefix(home + "/") || isInScratchSession(full) else { return .outsideHome }
        if parent == home && Self.protectedNames.contains(name) { return .protectedFolder }
        if full == home + "/Library/Caches" || full == home + "/Library/Logs" { return .protectedFolder }
        var info = stat()
        guard lstat(full, &info) == 0 else { return .missing }
        return nil
    }

    private func isInScratchSession(_ path: String) -> Bool {
        guard path.hasPrefix(agentScratch + "/") else { return false }
        // Anyone can create folders in /private/tmp, so only trust one this user owns.
        var info = stat()
        guard lstat(agentScratch, &info) == 0, info.st_uid == getuid() else { return false }
        return path.dropFirst(agentScratch.count + 1).split(separator: "/").count >= 2
    }

    /// Moves each path to the Trash. `sizes` reports what each one held, for the total. Deeper
    /// paths go first, so a folder and something inside it can be trashed in one run. Anything a
    /// running program has open stays, since the program would keep using the trashed copy.
    public func trash(
        _ paths: [String], sizes: [String: Int64] = [:], openFiles: OpenFiles = .current()
    ) -> Report {
        dispose(paths, sizes: sizes, names: [:], openFiles: openFiles, permanently: false)
    }

    /// Deletes each path outright, with the same safety checks as moving it to the Trash. For when
    /// the space is needed now, or the disk is too full for the Trash.
    public func delete(
        _ paths: [String], sizes: [String: Int64] = [:], openFiles: OpenFiles = .current()
    ) -> Report {
        dispose(paths, sizes: sizes, names: [:], openFiles: openFiles, permanently: true)
    }

    private func dispose(
        _ paths: [String], sizes: [String: Int64], names: [String: String], openFiles: OpenFiles, permanently: Bool
    ) -> Report {
        var report = Report()
        report.deleted = permanently
        let deepestFirst = paths.enumerated().sorted { first, second in
            let depths = (first.element.split(separator: "/").count, second.element.split(separator: "/").count)
            return depths.0 == depths.1 ? first.offset < second.offset : depths.0 > depths.1
        }
        for path in deepestFirst.map(\.element) {
            if let refusal = refusal(for: path) {
                report.failed.append((path, refusal.description))
                continue
            }
            let users = openFiles.users(of: Self.resolved(path))
            if let user = users.first?.name {
                let sessions = users.filter { $0.name == OpenFiles.claudeCode }
                if user == OpenFiles.claudeCode, let name = names[path] {
                    let reason = runningReason(name, sessions: sessions)
                    report.failed.append((path, reason))
                    report.namedReasons.insert(reason)
                } else {
                    report.failed.append((path, "\(user) is using it. Quit \(user), then try again."))
                }
                continue
            }
            do {
                if permanently {
                    try Deleter.remove(path)
                } else {
                    var trashed: NSURL?
                    try FileManager.default.trashItem(at: URL(filePath: path), resultingItemURL: &trashed)
                    report.inTrash[path] = trashed?.path
                }
                report.moved.append(path)
                report.movedBytes += sizes[path] ?? 0
                report.movedSizes[path] = sizes[path]
            } catch {
                report.failed.append((path, error.localizedDescription))
                if Self.isOutOfSpace(error) { report.diskFull = true }
            }
        }
        return report
    }

    /// Moves cleanup entries to the Trash, or deletes them, each with its companions. Companions go
    /// only when their entry did.
    public func trash(
        _ entries: [CleanupEntry], permanently: Bool = false, openFiles: OpenFiles = .current()
    ) -> Report {
        let sizes = Dictionary(entries.map { ($0.path, $0.bytes) }) { first, _ in first }
        let names = Dictionary(entries.map { ($0.path, $0.name) }) { first, _ in first }
        var report = dispose(
            entries.map(\.path), sizes: sizes, names: names, openFiles: openFiles, permanently: permanently
        )
        let moved = Set(report.moved)
        let companions = dispose(
            entries.filter { moved.contains($0.path) }.flatMap(\.companions), sizes: [:], names: [:],
            openFiles: openFiles, permanently: permanently
        )
        report.moved += companions.moved
        report.inTrash.merge(companions.inTrash) { first, _ in first }
        report.failed += companions.failed
        report.namedReasons.formUnion(companions.namedReasons)
        report.diskFull = report.diskFull || companions.diskFull
        return report
    }

    /// Claude Code runs in a terminal, so there's no app to quit: name the sessions by the app
    /// they're in, their folder, and since when. "Claude Code 2.1.304 is still running in 3 sessions:
    /// 2 in Terminal at ~ (since Oct 20) and 1 in Terminal at ~/code/app (since Oct 22). Type /exit in
    /// each, then try again."
    func runningReason(_ name: String, sessions: [OpenFiles.Program]) -> String {
        let oldestFirst = sessions.sorted { ($0.started ?? .distantPast) < ($1.started ?? .distantPast) }
        struct Group {
            let place: String
            let since: Date?
            var count = 1
        }
        var groups: [Group] = []
        for session in oldestFirst {
            var place: [String] = []
            if let app = session.app { place.append("in " + app) }
            if let folder = session.folder {
                place.append("at " + (folder == home ? "~" : folder.hasPrefix(home + "/")
                    ? "~" + folder.dropFirst(home.count) : folder))
            }
            let key = place.joined(separator: " ")
            if let index = groups.firstIndex(where: { $0.place == key }) {
                groups[index].count += 1
            } else {
                groups.append(Group(place: key, since: session.started))
            }
        }
        let described = groups.prefix(3).map { group in
            let since = group.since.map { " (since " + $0.formatted(.dateTime.month(.abbreviated).day()) + ")" } ?? ""
            let count = sessions.count > 1 ? "\(group.count) " : ""
            return (count + group.place + since).trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        let shown = groups.prefix(described.count).reduce(0) { $0 + $1.count }
        var list = described
        if shown < sessions.count, !list.isEmpty { list.append("\(sessions.count - shown) more") }
        if sessions.count == 1 {
            let place = list.first.map { " " + $0 } ?? ""
            return "\(name) is still running in a Claude Code session\(place). Type /exit in it, then try again."
        }
        let places = list.isEmpty ? "" : ": " + list.formatted(.list(type: .and))
        return "\(name) is still running in \(sessions.count) Claude Code sessions\(places). Type /exit in each, "
            + "then try again."
    }

    /// The entries a running program is using, under that program's name, so a confirmation can
    /// say up front what will stay.
    public static func busy(_ entries: [CleanupEntry], openFiles: OpenFiles) -> [String: [CleanupEntry]] {
        var busy: [String: [CleanupEntry]] = [:]
        for entry in entries {
            if let user = openFiles.user(of: resolved(entry.path)) { busy[user, default: []].append(entry) }
        }
        return busy
    }

    static func isOutOfSpace(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC) { return true }
        return (error.userInfo[NSUnderlyingErrorKey] as? Error).map(isOutOfSpace) ?? false
    }

    /// Moves what a trash run moved back where it was, outer folders first. Returns what couldn't
    /// go back, and why.
    public func putBack(_ report: Report) -> [(path: String, reason: String)] {
        var failed: [(path: String, reason: String)] = []
        for path in report.moved.reversed() {
            guard let trashed = report.inTrash[path] else {
                failed.append((path, "It isn't in the Trash anymore."))
                continue
            }
            var info = stat()
            if lstat(path, &info) == 0 {
                // An app may have made a fresh cache folder in the same place.
                failed.append((path, "Something new is already there. It's still in the Trash."))
                continue
            }
            do {
                let parent = (path as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
                try FileManager.default.moveItem(atPath: trashed, toPath: path)
            } catch {
                failed.append((path, error.localizedDescription))
            }
        }
        return failed
    }

    /// The path with its links resolved, so a link can't smuggle something out of home.
    static func resolved(_ path: String) -> String {
        guard let real = realpath(path, nil) else { return path }
        defer { free(real) }
        return String(cString: real)
    }
}
