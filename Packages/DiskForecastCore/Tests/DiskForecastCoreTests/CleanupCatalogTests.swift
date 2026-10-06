import Darwin
@testable import DiskForecastCore
import Foundation
import Testing

struct CleanupCatalogTests {
    let home: URL
    let now = Date()

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "DiskForecastHome-\(UUID().uuidString)")
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

    private func items() async -> [String: CleanupItem] {
        let scan = await DiskScanner(options: .init(root: home, diskImageThreshold: 1_000_000)).scan()
        let items = CleanupCatalog(home: home.path, now: now).items(from: scan)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    @Test func countsARecentInstallAsActive() async throws {
        let old = now.addingTimeInterval(-90 * 86_400)
        try write("code/app/package.json", bytes: 10, modified: old)
        try write("code/app/node_modules/pkg/index.js", bytes: 2_000_000)
        let items = await items()
        #expect(items["stale-builds"] == nil)
        #expect(items["active-builds"]?.entries.count == 1)
    }

    @Test func groupsKnownLocations() async throws {
        let old = now.addingTimeInterval(-90 * 86_400)
        try write("Library/Caches/com.example.app/blob", bytes: 2_000_000)
        try write("Library/Caches/com.apple.Safari/blob", bytes: 2_000_000)
        try write("Library/Logs/Example/log.txt", bytes: 1_500_000)
        try write(".cache/huggingface/hub/models--org--model/weights", bytes: 3_000_000)
        try write(".cache/pip/http/blob", bytes: 1_200_000)
        try write("code/old/package.json", bytes: 10, modified: old)
        try write("code/old/node_modules/pkg/index.js", bytes: 2_000_000)
        let installed = home.path + "/code/old/node_modules"
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: installed)
        try write("code/new/package.json", bytes: 10)
        try write("code/new/node_modules/pkg/index.js", bytes: 2_000_000)
        try write("Downloads/Installer.dmg", bytes: 12_000_000)
        try write("Downloads/movie.mov", bytes: 11_000_000)

        let items = await items()
        #expect(items["app-caches"]?.entries.map(\.name) == ["com.example.app"])
        #expect(items["app-caches"]?.group == .safeToClear)
        #expect(items["logs"]?.entries.map(\.name) == ["Example"])
        #expect(items["huggingface"]?.entries.map(\.name) == ["models--org--model"])
        #expect(items["huggingface"]?.group == .worthALook)
        #expect(items["package-caches"]?.entries.map(\.name) == ["pip"])
        #expect(items["stale-builds"]?.entries.map(\.path) == [home.path + "/code/old/node_modules"])
        #expect(items["active-builds"]?.entries.map(\.path) == [home.path + "/code/new/node_modules"])
        // The installer is explained as a disk image, so Downloads doesn't list it again.
        #expect(items["disk-images"]?.entries.map(\.name) == ["Installer.dmg"])
        #expect(items["downloads"]?.entries.map(\.name) == ["movie.mov"])
    }

    @Test func subtractsWhatAMoreSpecificRuleClaimed() async throws {
        try write("Downloads/project/package.json", bytes: 10)
        try write("Downloads/project/node_modules/pkg/index.js", bytes: 15_000_000)
        try write("Downloads/project/src/main.js", bytes: 11_000_000)
        let items = await items()
        let project = try #require(items["downloads"]?.entries.first)
        #expect(project.bytes >= 11_000_000 && project.bytes < 12_000_000)
        #expect(items["active-builds"]?.entries.count == 1)
    }

    @Test func describesAges() {
        let now = Date()
        #expect(Age.phrase(from: now, to: now) == "today")
        #expect(Age.phrase(from: now.addingTimeInterval(-3 * 86_400), to: now) == "3 days ago")
        #expect(Age.phrase(from: now.addingTimeInterval(-120 * 86_400), to: now) == "4 months ago")
    }
}
