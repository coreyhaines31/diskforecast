import Foundation
import os

/// The cleanup list's git worktrees: finished ones, the rest, and records left by deleted ones.
extension CleanupCatalog {
    /// How long a finished worktree has to sit untouched before it's offered as safe to clear.
    static let finishedWorktreeIdle: TimeInterval = 2 * 86_400

    /// Git worktree checkouts, each with what removing it would lose. `finished` picks the ones
    /// with nothing left only in them (clean, pushed, already merged, no pull request known to be
    /// open, nothing git ignores worth keeping, no submodules, and unused for two days) or the rest.
    func worktrees(_ scan: ScanResult, finished: Bool) -> [Candidate] {
        scan.worktrees.compactMap { worktree in
            var parts = [worktree.repository]
            let state = worktreeStates[worktree.path] ?? gitState(worktree.path)
            if let state { parts.append(state.summary) }
            let pullRequest = pullRequest(worktree.path)
            var isFinished = state?.isFinished == true && pullRequest != .open
                && now.timeIntervalSince(Self.lastUsed(worktree)) >= Self.finishedWorktreeIdle
            if isFinished, let kept = Self.keptOnlyHere(path: worktree.path, gitDirectory: worktree.gitDirectory) {
                // Says why an otherwise finished worktree still needs a look.
                parts.append(kept)
                isFinished = false
            }
            guard isFinished == finished else { return nil }
            if let phrase = pullRequest?.phrase { parts.append(phrase) }
            parts.append("last changed \(Age.phrase(from: worktree.modified, to: now))")
            // Its records go too, as with git worktree remove; they can hold whole submodule copies.
            // Only when they point back at this checkout, as git's own do, so a stray .git file
            // can't send something else to the Trash.
            let pointsBack = Self.checkoutGitFile(recordedIn: worktree.gitDirectory) == worktree.path + "/.git"
            return Candidate(
                path: worktree.path, detail: parts.joined(separator: " · "),
                companions: pointsBack ? [worktree.gitDirectory] : [], pullRequest: pullRequest,
                finishedWorktree: finished
            )
        }
    }

    /// When a worktree was last used: the newest of its top-level files and git's own log of the
    /// checkouts, commits and resets made in it. The index isn't counted, since editors and agent
    /// hosts rewrite it in the background.
    static func lastUsed(_ worktree: WorktreeFinding) -> Date {
        let records = [worktree.gitDirectory + "/logs/HEAD", worktree.gitDirectory + "/HEAD"]
        let dates = records.compactMap {
            (try? FileManager.default.attributesOfItem(atPath: $0))?[.modificationDate] as? Date
        }
        return ([worktree.modified] + dates).max() ?? worktree.modified
    }

    /// What a clean, merged worktree still holds that exists nowhere else, in words, or nil when
    /// there's nothing. Submodules keep their own history inside the worktree's records, where the
    /// checkout's git status doesn't look, so any at all count. When git can't say what it ignores,
    /// that counts too.
    static func keptOnlyHere(path: String, gitDirectory: String) -> String? {
        let files = FileManager.default
        let modules = (try? files.contentsOfDirectory(atPath: gitDirectory + "/modules")) ?? []
        if !modules.isEmpty || files.fileExists(atPath: path + "/.gitmodules") { return "has submodules" }
        switch GitState.ignoredKeepsakes(at: path) {
        case 0?: return nil
        case 1?: return "keeps 1 file git ignores"
        case let count?: return "keeps \(count) files git ignores"
        case nil: return "files git ignores unknown"
        }
    }

    /// Git's records for worktrees whose folder is gone, which is what `git worktree prune`
    /// removes. Locked worktrees and ones on a drive that isn't connected are left out.
    func leftoverWorktreeData(_ scan: ScanResult) -> [Candidate] {
        let tree = scan.tree
        let recordFolders = tree.names.indices.filter { node in
            guard node > 0, tree.names[node] == "worktrees" else { return false }
            let parent = tree.names[Int(tree.parents[node])]
            return parent == ".git" || parent.hasSuffix(".git")
        }
        // A checkout moved by hand still points at its records; they aren't left over.
        let inUse = Set(scan.worktrees.map(\.gitDirectory))
        return recordFolders.flatMap { records in
            tree.children[records].map(Int.init).compactMap { node -> Candidate? in
                let folder = tree.path(of: node)
                guard !inUse.contains(folder), !FileManager.default.fileExists(atPath: folder + "/locked"),
                      let checkoutGit = Self.checkoutGitFile(recordedIn: folder),
                      !checkoutGit.hasPrefix("/Volumes/"), Self.isMissing(checkoutGit)
                else { return nil }
                let checkout = (checkoutGit as NSString).deletingLastPathComponent
                return Candidate(
                    path: folder,
                    detail: "\(WorktreeFinding.repository(of: folder)) · worktree folder deleted",
                    name: (checkout as NSString).lastPathComponent
                )
            }
        }
    }

    /// The checkout's `.git` file that a worktree's records say they belong to.
    static func checkoutGitFile(recordedIn records: String) -> String? {
        guard let pointer = try? String(contentsOfFile: records + "/gitdir", encoding: .utf8) else { return nil }
        let target = pointer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }
        return ((target.hasPrefix("/") ? target : records + "/" + target) as NSString).standardizingPath
    }
}

extension Trasher {
    /// The worktrees among `entries` that were listed as finished and no longer are, and why each
    /// stays. The list can be hours old, and someone may have worked in one since.
    func changedWorktrees(in entries: [CleanupEntry]) -> [(path: String, reason: String)] {
        // One that's refused anyway is reported as that.
        let worktrees = entries.filter { $0.finishedWorktree && refusal(for: $0.path) == nil }
        let reasons = OSAllocatedUnfairLock(initialState: [Int: String]())
        // A few git calls each, so they run side by side.
        DispatchQueue.concurrentPerform(iterations: worktrees.count) { index in
            guard let reason = Self.unfinishedReason(worktrees[index]) else { return }
            reasons.withLock { $0[index] = reason }
        }
        let found = reasons.withLock { $0 }
        return worktrees.indices.compactMap { index in
            found[index].map { (worktrees[index].path, "Left alone: since the list was made, it \($0).") }
        }
    }

    /// Why a worktree listed as finished isn't any more, or nil when it still is. When git can't
    /// say, that counts as not finished.
    static func unfinishedReason(_ entry: CleanupEntry) -> String? {
        guard let state = GitState.read(at: entry.path) else { return "can no longer be read by git" }
        guard state.isFinished else { return "changed (\(state.summary))" }
        let gitFile = try? String(contentsOfFile: entry.path + "/.git", encoding: .utf8)
        guard let records = gitFile.flatMap({ WorktreeFinding.gitDirectory(fromGitFile: $0, checkout: entry.path) })
        else { return "is no longer a worktree" }
        return CleanupCatalog.keptOnlyHere(path: entry.path, gitDirectory: records).map { "\($0)" }
    }
}
