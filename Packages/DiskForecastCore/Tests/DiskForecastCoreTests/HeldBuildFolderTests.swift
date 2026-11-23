@testable import DiskForecastCore
import Foundation
import Testing

struct HeldBuildFolderTests {
    let home: URL
    let now = Date()

    init() throws {
        let base = TestFolders.make("DiskForecastHeld")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        home = URL(filePath: Trasher.resolved(base.path))
    }

    private func write(_ relativePath: String, bytes: Int, modified: Date? = nil) throws {
        let url = home.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    @Test func holdsBackABuildFolderWithACheckoutInside() async throws {
        let old = now.addingTimeInterval(-90 * 86_400)
        try write("code/api/pyproject.toml", bytes: 10, modified: old)
        try write("code/api/.venv/lib/site.py", bytes: 2_000_000, modified: old)
        try write("code/api/.venv/src/forked-lib/.git/HEAD", bytes: 10, modified: old)
        try write("code/web/package.json", bytes: 10, modified: old)
        try write("code/web/node_modules/pkg/index.js", bytes: 2_000_000, modified: old)
        for folder in ["code/api", "code/api/.venv", "code/web", "code/web/node_modules"] {
            try FileManager.default.setAttributes(
                [.modificationDate: old], ofItemAtPath: home.appending(path: folder).path
            )
        }
        let scan = await DiskScanner(options: .init(root: home)).scan()
        let items = Dictionary(
            uniqueKeysWithValues: CleanupCatalog(home: home.path, now: now).items(from: scan).map { ($0.id, $0) }
        )
        let held = try #require(items["held-builds"])
        #expect(held.group == .worthALook)
        #expect(held.entries.map(\.detail) == ["api · holds a git checkout at src/forked-lib"])
        #expect(held.entries.first?.rebuildable == nil)
        let stale = try #require(items["stale-builds"])
        #expect(stale.entries.map(\.path) == [home.path + "/code/web/node_modules"])
        #expect(stale.entries.first?.rebuildable == .nodeModules)
    }

    @Test func holdsBackWhateverTheCheckRefuses() async throws {
        try write("code/app/package.json", bytes: 10)
        try write("code/app/node_modules/pkg/index.js", bytes: 2_000_000)
        let scan = await DiskScanner(options: .init(root: home)).scan()
        let catalog = CleanupCatalog(home: home.path, now: now, buildFolderHold: { _, _ in .tracked })
        let items = Dictionary(uniqueKeysWithValues: catalog.items(from: scan).map { ($0.id, $0) })
        #expect(items["active-builds"] == nil)
        #expect(items["held-builds"]?.entries.map(\.detail) == ["app · has files git tracks"])
    }

    @Test func leavesABuildFolderThatGainedACheckoutSinceItWasListed() throws {
        try write("code/api/.venv/lib/site.py", bytes: 10)
        try write("code/web/node_modules/pkg/index.js", bytes: 10)
        let venv = CleanupEntry(path: home.path + "/code/api/.venv", bytes: 10, rebuildable: .pythonVenv)
        let modules = CleanupEntry(path: home.path + "/code/web/node_modules", bytes: 10, rebuildable: .nodeModules)
        // Cloned in after the list was made.
        try write("code/api/.venv/src/forked-lib/.git/HEAD", bytes: 10)
        let report = Trasher(home: home.path).trash([venv, modules], openFiles: OpenFiles(processes: []))
        #expect(report.moved == [modules.path])
        #expect(report.failed.map(\.path) == [venv.path])
        #expect(report.failed.map(\.reason) == ["Left alone: it holds a git checkout at src/forked-lib."])
        #expect(FileManager.default.fileExists(atPath: venv.path + "/src/forked-lib/.git/HEAD"))
    }

    @Test func removesAHeldBuildFolderTheUserPicked() throws {
        try write("code/api/.venv/src/forked-lib/.git/HEAD", bytes: 10)
        // Listed under Worth a look with its reason, so it isn't marked rebuildable.
        let venv = CleanupEntry(path: home.path + "/code/api/.venv", bytes: 10)
        let report = Trasher(home: home.path).trash([venv], openFiles: OpenFiles(processes: []))
        #expect(report.moved == [venv.path])
    }
}
