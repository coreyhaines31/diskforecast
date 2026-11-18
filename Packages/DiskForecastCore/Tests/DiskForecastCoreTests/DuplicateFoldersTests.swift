import Darwin
@testable import DiskForecastCore
import Foundation
import Testing

struct DuplicateFoldersTests {
    let home: URL
    let minimum: Int64 = 400_000

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "DiskForecastHome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        home = URL(filePath: Trasher.resolved(base.path))
    }

    /// Writes the same random files under each folder, as separate copies that share no storage.
    private func write(_ files: [String: Int], in folders: [String]) throws {
        for (file, bytes) in files {
            var data = Data(count: bytes)
            data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
            for folder in folders {
                let url = home.appending(path: folder + "/" + file)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try data.write(to: url)
            }
        }
        // The first folder is the older one.
        for (index, folder) in folders.enumerated() {
            let created = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
            try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: home.path + "/" + folder)
        }
    }

    private let trip = ["a.bin": 300_000, "photos/b.bin": 200_000, "photos/c.bin": 50_000]

    private func find() async -> [DuplicateFolder] {
        let scan = await DiskScanner(options: .init(root: home)).scan()
        return DuplicateFolders.find(in: scan, home: home.path, minimumBytes: minimum)
    }

    @Test func findsAFolderStoredTwice() async throws {
        try write(trip, in: ["Desktop/Trip", "Downloads/Trip"])
        let found = await find()
        #expect(found.map(\.path) == [home.path + "/Downloads/Trip"])
        #expect(found.first?.original == home.path + "/Desktop/Trip")
        #expect((found.first?.bytes ?? 0) >= 550_000)
    }

    @Test func skipsClonesThatShareStorage() async throws {
        try write(trip, in: ["Desktop/Trip"])
        let downloads = home.appending(path: "Downloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let cloned = clonefile(home.path + "/Desktop/Trip", home.path + "/Downloads/Trip", 0)
        #expect(cloned == 0)
        let scan = await DiskScanner(options: .init(root: home)).scan()
        #expect(DuplicateFolders.find(in: scan, home: home.path, minimumBytes: minimum).isEmpty)
        // Even compared directly, the clone frees next to nothing.
        let tree = scan.tree
        let copy = try #require(tree.node(at: home.path + "/Downloads/Trip"))
        let original = try #require(tree.node(at: home.path + "/Desktop/Trip"))
        let freed = try #require(DuplicateFolders.freedBytes(removing: copy, keeping: original, in: tree))
        #expect(freed < 100_000)
    }

    @Test func skipsFoldersWhoseContentDiffers() async throws {
        try write(trip, in: ["Desktop/Trip", "Downloads/Trip"])
        let handle = try FileHandle(forWritingTo: home.appending(path: "Downloads/Trip/a.bin"))
        try handle.seek(toOffset: 150_000)
        try handle.write(contentsOf: Data([0, 1, 2, 3]))
        try handle.close()
        #expect(await find().isEmpty)
    }

    @Test func skipsFoldersWithDifferentFiles() async throws {
        try write(trip, in: ["Desktop/Trip", "Downloads/Trip"])
        try FileManager.default.moveItem(
            at: home.appending(path: "Downloads/Trip/photos/c.bin"), to: home.appending(path: "Downloads/Trip/d.bin")
        )
        #expect(await find().isEmpty)
    }

    @Test func skipsSmallHiddenAndLibraryFolders() async throws {
        try write(["a.bin": 100_000], in: ["Desktop/Small", "Downloads/Small"])
        try write(trip, in: [".config/Trip", ".backup/Trip"])
        try write(trip, in: ["Library/Trip", "Documents/Library/Trip"])
        try write(trip, in: ["Applications/Tool.app", "Downloads/Tool.app"])
        #expect(await find().isEmpty)
    }

    @Test func skipsBuildFoldersAndWorktrees() async throws {
        try write(["package.json": 10], in: ["code/one", "code/two"])
        try write(trip, in: ["code/one/node_modules", "code/two/node_modules"])
        let found = await find()
        #expect(!found.contains { $0.path.hasSuffix("node_modules") })
    }

    @Test func listsOnlyTheOutermostCopy() async throws {
        try write(trip, in: ["Desktop/Trip", "Downloads/Trip"])
        try write(["photos/big.bin": 500_000], in: ["Desktop/Trip", "Downloads/Trip"])
        #expect(await find().map(\.path) == [home.path + "/Downloads/Trip"])
    }

    @Test func listsEveryExtraCopy() async throws {
        try write(trip, in: ["Desktop/Trip", "Downloads/Trip", "Documents/Trip"])
        let found = await find()
        #expect(Set(found.map(\.path)) == [home.path + "/Downloads/Trip", home.path + "/Documents/Trip"])
        #expect(found.allSatisfy { $0.original == home.path + "/Desktop/Trip" })
    }
}
