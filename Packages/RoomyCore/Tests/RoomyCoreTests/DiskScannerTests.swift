import Darwin
import Foundation
@testable import RoomyCore
import Testing

struct DiskScannerTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "RoomyScan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func write(_ relativePath: String, bytes: Int, modified: Date? = nil) throws {
        let url = root.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Random bytes so APFS can't compress or share them.
        var data = Data(count: bytes)
        data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
        try data.write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    private func scan(excluding: Set<String> = []) async -> ScanResult {
        let options = DiskScanner.Options(
            root: root, excludedPaths: excluding,
            largeFileThreshold: 500_000, diskImageThreshold: 100_000, workerCount: 4
        )
        return await DiskScanner(options: options).scan()
    }

    private var rootPath: String {
        let path = root.standardizedFileURL.path(percentEncoded: false)
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    @Test func sumsAllocatedBytesUpTheTree() async throws {
        try write("a/one.bin", bytes: 1_000_000)
        try write("a/b/two.bin", bytes: 2_000_000)
        try write("c/three.bin", bytes: 300_000)
        let result = await scan()
        let tree = result.tree
        #expect(result.fileCount == 3)
        #expect(tree.directoryCount == 4)
        let outer = try #require(tree.size(of: rootPath + "/a"))
        let inner = try #require(tree.size(of: rootPath + "/a/b"))
        #expect(inner >= 2_000_000 && inner < 2_100_000)
        #expect(outer >= 3_000_000 && outer < 3_100_000)
        #expect(tree.totalSize == outer + (tree.size(of: rootPath + "/c") ?? 0))
        #expect(result.largestFiles.map(\.path) == [rootPath + "/a/b/two.bin", rootPath + "/a/one.bin"])
    }

    @Test func countsHardLinksOnce() async throws {
        try write("original.bin", bytes: 1_000_000)
        try FileManager.default.createDirectory(at: root.appending(path: "links"), withIntermediateDirectories: true)
        #expect(link(root.appending(path: "original.bin").path, root.appending(path: "links/copy.bin").path) == 0)
        let result = await scan()
        #expect(result.fileCount == 2)
        #expect(result.tree.totalSize >= 1_000_000 && result.tree.totalSize < 1_100_000)
    }

    @Test func countsClonesOnce() async throws {
        try write("original.bin", bytes: 1_000_000)
        #expect(clonefile(root.appending(path: "original.bin").path, root.appending(path: "clone.bin").path, 0) == 0)
        let result = await scan()
        #expect(result.fileCount == 2)
        #expect(result.tree.totalSize >= 1_000_000 && result.tree.totalSize < 1_100_000)
    }

    @Test func findsBuildArtifactsBesideTheirProjectFiles() async throws {
        let old = Date(timeIntervalSinceNow: -90 * 86_400)
        try write("old-app/package.json", bytes: 10, modified: old)
        try write("old-app/node_modules/left-pad/index.js", bytes: 5_000)
        try write("old-app/node_modules/left-pad/node_modules/x/index.js", bytes: 5_000)
        try write("rust/Cargo.toml", bytes: 10)
        try write("rust/target/debug/app", bytes: 5_000)
        try write("not-a-project/target/thing", bytes: 5_000)
        try write("not-a-project/node_modules/thing", bytes: 5_000)
        let result = await scan()
        #expect(result.artifacts.map(\.path) == [rootPath + "/old-app/node_modules", rootPath + "/rust/target"])
        let nodeModules = try #require(result.artifacts.first)
        #expect(nodeModules.kind == .nodeModules)
        #expect(abs(nodeModules.projectModified.timeIntervalSince(old)) < 2)
        #expect(result.size(of: nodeModules) >= 10_000)
    }

    @Test func findsDiskImages() async throws {
        try write("Downloads/Installer.dmg", bytes: 200_000)
        try write("Downloads/small.dmg", bytes: 1_000)
        try write("Downloads/big.mov", bytes: 200_000)
        let result = await scan()
        #expect(result.diskImages.map(\.path) == [rootPath + "/Downloads/Installer.dmg"])
    }

    @Test func skipsExcludedFolders() async throws {
        try write("keep/a.bin", bytes: 100_000)
        try write("private/b.bin", bytes: 100_000)
        let result = await scan(excluding: [rootPath + "/private"])
        #expect(result.fileCount == 1)
        #expect(result.skippedPaths == [rootPath + "/private"])
        #expect(result.tree.size(of: rootPath + "/private") == nil)
    }

    @Test func doesNotFollowSymlinks() async throws {
        try write("real/a.bin", bytes: 100_000)
        try FileManager.default.createSymbolicLink(atPath: rootPath + "/alias", withDestinationPath: rootPath + "/real")
        let result = await scan()
        #expect(result.tree.size(of: rootPath + "/alias") == nil)
        #expect(result.fileCount == 2)
    }

    @Test func countsUnreadableFolders() async throws {
        try write("locked/a.bin", bytes: 100)
        chmod(rootPath + "/locked", 0)
        defer { chmod(rootPath + "/locked", 0o755) }
        let result = await scan()
        #expect(result.deniedCount == 1)
        #expect(result.deniedSamples == [rootPath + "/locked"])
    }
}
