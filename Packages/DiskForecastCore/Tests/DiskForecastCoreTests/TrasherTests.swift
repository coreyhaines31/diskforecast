@testable import DiskForecastCore
import Foundation
import Testing

struct TrasherTests {
    let home: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "DiskForecastTrash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        home = URL(filePath: Trasher.resolved(base.path))
    }

    private func write(_ relativePath: String, bytes: Int) throws {
        let url = home.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    @Test func movesToTheTrash() throws {
        try write("Library/Caches/com.example.app/blob", bytes: 10)
        let path = home.path + "/Library/Caches/com.example.app"
        let report = Trasher(home: home.path).trash([path], sizes: [path: 10])
        #expect(report.moved == [path])
        #expect(report.movedBytes == 10)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func leavesWhatARunningProgramUses() throws {
        try write("Library/Caches/com.example.app/blob", bytes: 10)
        try write("Library/Caches/com.example.other/blob", bytes: 10)
        let open = home.path + "/Library/Caches/com.example.app"
        let closed = home.path + "/Library/Caches/com.example.other"
        let openFiles = OpenFiles(processes: [(name: "Example", paths: [open + "/blob"])])
        let report = Trasher(home: home.path).trash([open, closed], openFiles: openFiles)
        #expect(report.moved == [closed])
        #expect(report.failed.map(\.reason) == ["Example is using it. Quit Example, then try again."])
        #expect(FileManager.default.fileExists(atPath: open))
    }

    @Test func namesTheClaudeCodeSessionsStillRunningAVersion() throws {
        try write(".local/share/claude/versions/2.1.304", bytes: 10)
        let version = home.path + "/.local/share/claude/versions/2.1.304"
        let first = Date(timeIntervalSince1970: 1_792_000_000)
        let sessions = [(home.path, first), (home.path + "/code/app", first + 86_400), (home.path, first + 3_600)].map {
            OpenFiles.Program(name: "Claude Code", paths: [version], folder: $0.0, started: $0.1, app: "Terminal")
        }
        let entry = CleanupEntry(path: version, bytes: 10, name: "Claude Code 2.1.304")
        let trasher = Trasher(home: home.path)
        let report = trasher.trash([entry], openFiles: OpenFiles(programs: sessions))
        let day = { (date: Date) in date.formatted(.dateTime.month(.abbreviated).day()) }
        #expect(report.failureLines() == [
            "• Claude Code 2.1.304 is still running in 3 Claude Code sessions: 2 in Terminal at ~ (since "
                + "\(day(first))) and 1 in Terminal at ~/code/app (since \(day(first + 86_400))). Type /exit in "
                + "each, then try again."
        ])
        #expect(trasher.runningReason("Claude Code 2.1.304", sessions: [sessions[1]])
            == "Claude Code 2.1.304 is still running in a Claude Code session in Terminal at ~/code/app (since "
            + "\(day(first + 86_400))). Type /exit in it, then try again.")
        #expect(FileManager.default.fileExists(atPath: version))
    }

    @Test func saysWhichEntriesAreBusyBeforeMoving() {
        let cursor = CleanupEntry(path: home.path + "/Library/Caches/com.todesktop.cursor", bytes: 5)
        let idle = CleanupEntry(path: home.path + "/Library/Caches/com.example.idle", bytes: 5)
        let openFiles = OpenFiles(processes: [(name: "Cursor", paths: [cursor.path + "/Cache_Data/data_0"])])
        #expect(Trasher.busy([cursor, idle], openFiles: openFiles) == ["Cursor": [cursor]])
    }

    @Test func findsFilesAnotherProcessHasOpen() throws {
        try write("Library/Caches/com.example.app/blob", bytes: 10)
        let tail = Process()
        tail.executableURL = URL(filePath: "/usr/bin/tail")
        tail.arguments = ["-f", home.path + "/Library/Caches/com.example.app/blob"]
        try tail.run()
        defer { tail.terminate() }
        Thread.sleep(forTimeInterval: 0.3)
        let openFiles = OpenFiles.current()
        #expect(openFiles.user(of: home.path + "/Library/Caches/com.example.app") == "tail")
        #expect(openFiles.user(of: home.path + "/Library/Caches/com.example") == nil)
    }

    @Test func putsBackWhatItMoved() throws {
        try write("Library/Caches/com.example.app/blob", bytes: 10)
        try write("Library/Caches/com.example.other/blob", bytes: 10)
        let first = home.path + "/Library/Caches/com.example.app"
        let second = home.path + "/Library/Caches/com.example.other"
        let trasher = Trasher(home: home.path)
        let report = trasher.trash([first, second])
        // The app made a new cache in the meantime, so that one stays in the Trash.
        try write("Library/Caches/com.example.other/new", bytes: 10)

        let failed = trasher.putBack(report)
        #expect(FileManager.default.fileExists(atPath: first + "/blob"))
        #expect(failed.map(\.path) == [second])
        if let trashed = report.inTrash[second] { try? FileManager.default.removeItem(atPath: trashed) }
    }

    @Test func trashesAFolderAndSomethingInsideItTogether() throws {
        try write("code/app-worktree/node_modules/pkg/index.js", bytes: 10)
        try write("code/app-worktree/README.md", bytes: 10)
        let outer = home.path + "/code/app-worktree"
        let inner = outer + "/node_modules"
        let trasher = Trasher(home: home.path)
        let report = trasher.trash([outer, inner])
        #expect(report.failed.isEmpty)
        #expect(Set(report.moved) == [outer, inner])

        #expect(trasher.putBack(report).isEmpty)
        #expect(FileManager.default.fileExists(atPath: inner + "/pkg/index.js"))
        #expect(FileManager.default.fileExists(atPath: outer + "/README.md"))
    }

    @Test func refusesAnythingRisky() throws {
        let caches = home.appending(path: "Library/Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        let outside = FileManager.default.temporaryDirectory.appending(path: "outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: home.appending(path: "escape"), withDestinationURL: outside)
        let trasher = Trasher(home: home.path)
        #expect(trasher.refusal(for: home.path) == .outsideHome)
        #expect(trasher.refusal(for: home.path + "/Library") == .protectedFolder)
        #expect(trasher.refusal(for: home.path + "/Library/Caches") == .protectedFolder)
        #expect(trasher.refusal(for: outside.path) == .outsideHome)
        #expect(trasher.refusal(for: home.path + "/escape/thing") == .outsideHome)
        #expect(trasher.refusal(for: home.path + "/missing") == .missing)
        #expect(trasher.refusal(for: home.path + "/escape") == nil)
        let report = trasher.trash([home.path + "/Library"])
        #expect(report.moved.isEmpty)
        #expect(FileManager.default.fileExists(atPath: home.path + "/Library"))
    }

    @Test func movesClaudeCodeSessionsButNotTheirParents() throws {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "claude-\(UUID().uuidString)")
        let session = scratch.appending(path: "-Users-me-code-app/2f1c")
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        let trasher = Trasher(home: home.path, agentScratch: scratch.path)
        #expect(trasher.refusal(for: session.path) == nil)
        #expect(trasher.refusal(for: session.deletingLastPathComponent().path) == .outsideHome)
        #expect(trasher.refusal(for: scratch.path) == .outsideHome)
    }
}

struct TrasherReportTests {
    @Test func groupsFailuresByReasonAndNamesTheProject() {
        var report = Trasher.Report()
        let full = "There isn't enough space."
        for project in ["shop", "blog", "site", "api"] {
            report.failed.append(("/Users/me/code/\(project)/node_modules", full))
        }
        report.failed.append(("/Users/me/Library/Caches/x", "It's no longer there."))
        #expect(report.failureLines() == [
            "• shop/node_modules, blog/node_modules, site/node_modules and 1 more: There isn't enough space.",
            "• Caches/x: It's no longer there."
        ])
    }

    @Test func recognizesAFullDisk() {
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        #expect(Trasher.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 513, userInfo: [NSUnderlyingErrorKey: posix])
        #expect(Trasher.isOutOfSpace(wrapped))
        #expect(!Trasher.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: 513)))
    }
}
