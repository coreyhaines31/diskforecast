import Darwin
@testable import DiskForecastCore
import Foundation
import Testing

struct BuildTierTests {
    let home: URL
    let now = Date()

    init() throws {
        let base = TestFolders.make("DiskForecastTiers")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        home = URL(filePath: Trasher.resolved(base.path))
    }

    private func write(_ relativePath: String, bytes: Int, modified: Date? = nil) throws {
        let url = home.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
        try data.write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    /// A build folder holding one file, both last written at `written`.
    private func writeBuildFolder(_ relativePath: String, written: Date) throws {
        try write(relativePath + "/output.bin", bytes: 2_000_000, modified: written)
        try FileManager.default.setAttributes(
            [.modificationDate: written], ofItemAtPath: home.appending(path: relativePath).path
        )
    }

    private func items() async -> [String: CleanupItem] {
        let scan = await DiskScanner(options: .init(root: home)).scan()
        let items = CleanupCatalog(home: home.path, now: now).items(from: scan)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    @Test func outputThatRebuildsItselfIsSafeOnceNothingWritesToIt() async throws {
        try write("code/shop/package.json", bytes: 10)
        try writeBuildFolder("code/shop/.next", written: now.addingTimeInterval(-2 * 86_400))
        try writeBuildFolder("code/shop/node_modules", written: now.addingTimeInterval(-2 * 86_400))
        try write("code/site/package.json", bytes: 10)
        try writeBuildFolder("code/site/.next", written: now.addingTimeInterval(-3_600))

        let items = await items()
        let idle = try #require(items["idle-build-output"])
        #expect(idle.group == .safeToClear)
        #expect(idle.entries.map(\.path) == [home.path + "/code/shop/.next"])
        #expect(idle.entries.first?.detail == "shop · last changed today · comes back on the next run")
        // Dependencies need a reinstall, and output written an hour ago is in use: both wait for a look.
        let active = try #require(items["active-builds"])
        let paths = Set(active.entries.map(\.path))
        #expect(paths == [home.path + "/code/shop/node_modules", home.path + "/code/site/.next"])
        let modules = try #require(active.entries.first { $0.path.hasSuffix("node_modules") })
        #expect(modules.detail?.hasSuffix("needs a reinstall") == true)
        #expect(items["stale-builds"] == nil)
    }

    @Test func dependenciesInAProjectNobodyHasWorkedInGetTheirOwnItem() async throws {
        let quiet = home.path + "/code/shop"
        let busy = home.path + "/code/site"
        try write("code/shop/package.json", bytes: 10)
        try writeBuildFolder("code/shop/node_modules", written: now.addingTimeInterval(-2 * 86_400))
        try write("code/site/package.json", bytes: 10)
        try writeBuildFolder("code/site/node_modules", written: now.addingTimeInterval(-2 * 86_400))
        // A quiet project, but something installed into it an hour ago.
        try write("code/blog/package.json", bytes: 10)
        try writeBuildFolder("code/blog/node_modules", written: now.addingTimeInterval(-3_600))
        let now = now
        let scan = await DiskScanner(options: .init(root: home)).scan()
        let catalog = CleanupCatalog(home: home.path, now: now, projectActivity: { _ in
            [
                quiet: now.addingTimeInterval(-10 * 86_400), busy: now.addingTimeInterval(-86_400),
                quiet.replacingOccurrences(of: "shop", with: "blog"): now.addingTimeInterval(-10 * 86_400)
            ]
        })
        let items = Dictionary(uniqueKeysWithValues: catalog.items(from: scan).map { ($0.id, $0) })
        let item = try #require(items["quiet-builds"])
        #expect(item.group == .worthALook)
        #expect(item.entries.map(\.path) == [quiet + "/node_modules"])
        #expect(item.entries.first?.detail == "shop · last commit or agent session 10 days ago · needs a reinstall")
        #expect(item.entries.first?.rebuildable == .nodeModules)
        let active = Set(items["active-builds"]?.entries.map(\.path) ?? [])
        #expect(active == [busy + "/node_modules", home.path + "/code/blog/node_modules"])
    }

    @Test func aProjectOutsideGitIsNeverCalledQuiet() async throws {
        try write("code/loose/package.json", bytes: 10)
        try writeBuildFolder("code/loose/node_modules", written: now.addingTimeInterval(-2 * 86_400))
        let items = await items()
        #expect(items["quiet-builds"] == nil)
        #expect(items["active-builds"]?.entries.count == 1)
    }

    @Test func aBuildFolderThatCannotBeReadWaitsForALook() {
        #expect(CleanupCatalog.lastWritten(home.path + "/missing/.next") == nil)
    }

    @Test func everyKindSaysWhatGettingItBackTakes() {
        #expect(ArtifactKind.nextBuild.restoreCost == .regenerates)
        #expect(ArtifactKind.rustTarget.restoreCost == .rebuild)
        #expect(ArtifactKind.nodeModules.restoreCost == .install)
        #expect(ArtifactKind.RestoreCost.regenerates < .rebuild)
        #expect(ArtifactKind.RestoreCost.rebuild < .install)
    }
}

struct TrashContentsTests {
    @Test func whatIsAlreadyInTheTrashIsNotOfferedAgain() async throws {
        let base = TestFolders.make("DiskForecastTrashed")
        let home = URL(filePath: Trasher.resolved(base.path))
        let old = Date().addingTimeInterval(-90 * 86_400)
        for project in ["code/old", ".Trash/old-project"] {
            let folder = home.appending(path: project)
            try FileManager.default.createDirectory(
                at: folder.appending(path: "node_modules/pkg"), withIntermediateDirectories: true
            )
            try Data(count: 10).write(to: folder.appending(path: "package.json"))
            try Data(count: 2_000_000).write(to: folder.appending(path: "node_modules/pkg/index.js"))
            for path in [folder.path, folder.path + "/package.json", folder.path + "/node_modules"] {
                try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: path)
            }
        }
        let scan = await DiskScanner(options: .init(root: home)).scan()
        let entries = CleanupCatalog(home: home.path).items(from: scan).flatMap(\.entries)
        #expect(entries.map(\.path) == [home.path + "/code/old/node_modules"])
    }
}
