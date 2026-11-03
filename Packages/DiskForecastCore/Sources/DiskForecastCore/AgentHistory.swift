import Foundation

extension CleanupCatalog {
    /// Coding agent conversations nobody has opened in `staleAfterDays`: one entry per Claude Code
    /// project and per month of Codex sessions. Resuming a conversation writes to it, so one in use
    /// is never old.
    func agentHistory(_ scan: ScanResult) -> [Candidate] {
        claudeCodeHistory(scan) + codexHistory(scan)
    }

    /// Each conversation is a .jsonl file, with a folder of the same name for its subagents and tool
    /// output. The project folder itself stays: it also holds Claude Code's memory for the project.
    private func claudeCodeHistory(_ scan: ScanResult) -> [Candidate] {
        children(of: ".claude/projects", in: scan).compactMap { project in
            let old = Self.files(in: project.path, recursive: false)
                .filter { $0.path.hasSuffix(".jsonl") && $0.modified < staleCutoff }
                .sorted { $0.modified > $1.modified }
            guard let newest = old.first else { return nil }
            let companions = old.dropFirst().map(\.path) + old.map { String($0.path.dropLast(".jsonl".count)) }
            let folder = Self.workingFolder(ofConversation: newest.path)
            let name = folder.map { ($0 as NSString).lastPathComponent }
                ?? (project.path as NSString).lastPathComponent
            var detail = [Self.conversations(old.count) + ", the newest " + Age.phrase(from: newest.modified, to: now)]
            if let folder { detail.insert(abbreviated(folder), at: 0) }
            return Candidate(
                path: newest.path, detail: detail.joined(separator: " · "), name: "Claude Code: \(name)",
                companions: companions.filter { !Self.isMissing($0) }
            )
        }
    }

    /// Codex files its sessions by date, as sessions/2026/06/01/rollout-….jsonl, so a whole month
    /// goes once nothing in it is recent.
    private func codexHistory(_ scan: ScanResult) -> [Candidate] {
        children(of: ".codex/sessions", in: scan).flatMap { year in
            let relative = String(year.path.dropFirst(home.count + 1))
            return children(of: relative, in: scan).compactMap { month -> Candidate? in
                let sessions = Self.files(in: month.path, recursive: true).filter { $0.path.hasSuffix(".jsonl") }
                guard let newest = sessions.map(\.modified).max(), newest < staleCutoff else { return nil }
                let label = Self.monthName(year: year.path, month: month.path) ?? relative
                return Candidate(
                    path: month.path, detail: Self.conversations(sessions.count),
                    name: "Codex: \(label)"
                )
            }
        }
    }

    private func abbreviated(_ path: String) -> String {
        path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    private static func conversations(_ count: Int) -> String {
        count == 1 ? "1 conversation" : "\(count) conversations"
    }

    /// "June 2026" from the folders 2026 and 06.
    static func monthName(year: String, month: String) -> String? {
        let parts = DateComponents(
            year: Int((year as NSString).lastPathComponent), month: Int((month as NSString).lastPathComponent)
        )
        guard let date = Calendar(identifier: .gregorian).date(from: parts) else { return nil }
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// The folder a Claude Code conversation ran in, from the first of its lines that says.
    static func workingFolder(ofConversation path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let start = (try? handle.read(upToCount: 256_000)) ?? Data()
        for line in start.split(separator: UInt8(ascii: "\n")) {
            guard let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let folder = json["cwd"] as? String, folder.hasPrefix("/")
            else { continue }
            return folder
        }
        return nil
    }

    /// Files in a folder with when each last changed. Only called on folders the scan reached.
    static func files(in folder: String, recursive: Bool) -> [(path: String, modified: Date)] {
        let url = URL(filePath: folder)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let urls: [URL]
        if recursive {
            let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys)
            urls = (walker?.allObjects as? [URL]) ?? []
        } else {
            urls = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)) ?? []
        }
        return urls.compactMap { file in
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { return nil }
            return (file.path, modified)
        }
    }
}
