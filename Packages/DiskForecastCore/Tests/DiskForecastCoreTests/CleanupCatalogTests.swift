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

    @Test func namesScreenRecordingsByTheirApp() async throws {
        try write(".screenpipe/data/2026-10-22/monitor_1.mp4", bytes: 2_000_000)
        try write(".screenpipe/pipes/obsidian/pipe.json", bytes: 2_000_000)
        let items = await items()
        #expect(items["screen-recordings"]?.entries.map(\.name) == ["Screenpipe"])
        #expect(items["screen-recordings"]?.group == .worthALook)
    }

    @Test func findsWhatCodingAgentsLeaveBehind() async throws {
        let older = now.addingTimeInterval(-7 * 86_400)
        try write(".local/share/claude/versions/2.1.304", bytes: 2_000_000, modified: older)
        try write(".local/share/claude/versions/2.1.309", bytes: 2_000_000)
        try write(".npm/_npx/4f2a/node_modules/slack-mcp-server/index.js", bytes: 2_000_000)
        for (browser, modified) in [("chromium-1140", older), ("chromium-1148", now), ("webkit-2083", older)] {
            try write("Library/Caches/ms-playwright/\(browser)/chrome", bytes: 2_000_000)
            try FileManager.default.setAttributes(
                [.modificationDate: modified], ofItemAtPath: home.path + "/Library/Caches/ms-playwright/" + browser
            )
        }

        let items = await items()
        let names = Set(items["agent-leftovers"]?.entries.map(\.name) ?? [])
        #expect(names == ["npx packages", "Claude Code 2.1.304", "Playwright chromium-1140"])
        #expect(items["app-caches"] == nil)
        #expect(items["package-caches"] == nil)
    }

    @Test func groupsKnownLocations() async throws {
        let old = now.addingTimeInterval(-90 * 86_400)
        try write("Library/Caches/com.example.app/blob", bytes: 2_000_000)
        try write("Library/Caches/com.apple.Safari/blob", bytes: 2_000_000)
        try write("Library/Logs/Example/log.txt", bytes: 1_500_000)
        try write(".cache/huggingface/hub/models--org--model/weights", bytes: 3_000_000)
        try write(".cache/pip/http/blob", bytes: 1_200_000)
        try write("Library/pnpm/store/v10/files/00/blob", bytes: 2_000_000)
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

    @Test func findsCachesBesideWebAppData() async throws {
        let support = "Library/Application Support/"
        try write(support + "Cursor/Local Storage/leveldb/000001.log", bytes: 10)
        try write(support + "Cursor/Cache/Cache_Data/data_0", bytes: 2_000_000)
        try write(support + "Cursor/CachedExtensionVSIXs/ext.vsix", bytes: 1_500_000)
        try write(support + "Cursor/User/settings.json", bytes: 1_200_000)
        try write(support + "Figma/DesktopProfile/v39/Session Storage/000001.log", bytes: 10)
        try write(support + "Figma/DesktopProfile/v39/Code Cache/js/index", bytes: 1_800_000)
        // Not beside Local Storage or Session Storage, so it isn't treated as a web cache.
        try write(support + "Notes Pro/Cache/notes.db", bytes: 3_000_000)

        let items = await items()
        let entries = try #require(items["app-support-caches"]?.entries)
        #expect(Set(entries.map { "\($0.name)/\($0.detail ?? "")" })
            == ["Cursor/Cache", "Cursor/CachedExtensionVSIXs", "Figma/DesktopProfile/v39/Code Cache"])
        #expect(items["app-support-caches"]?.group == .safeToClear)
    }

    @Test func findsEditorDataForDeletedProjects() async throws {
        let storage = "Library/Application Support/Code/User/workspaceStorage/"
        let existing = home.appending(path: "code/kept").path
        try FileManager.default.createDirectory(atPath: existing, withIntermediateDirectories: true)
        let projects = [
            ("gone", "{\"folder\": \"file://\(home.path)/code/gone\"}"),
            ("kept", "{\"folder\": \"file://\(existing)\"}"),
            ("drive", "{\"folder\": \"file:///Volumes/External/project\"}"),
            ("remote", "{\"folder\": \"vscode-remote://ssh-remote+box/home/project\"}")
        ]
        for (hash, json) in projects {
            try write(storage + hash + "/state.vscdb", bytes: 1_500_000)
            try Data(json.utf8).write(to: home.appending(path: storage + hash + "/workspace.json"))
        }

        let items = await items()
        #expect(items["orphaned-workspaces"]?.entries.map(\.name) == ["gone"])
        #expect(items["orphaned-workspaces"]?.entries.first?.detail == "Code · project deleted")
        #expect(items["orphaned-workspaces"]?.group == .worthALook)
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

struct CleanupItemPreviewTests {
    private func item(_ entries: [CleanupEntry]) -> CleanupItem {
        CleanupItem(id: "x", title: "X", explanation: "", group: .safeToClear, action: .trash, entries: entries)
    }

    @Test func namesTheLargestAndCountsTheRest() {
        let preview = item([
            CleanupEntry(path: "/u/code/blog/node_modules", bytes: 2),
            CleanupEntry(path: "/u/code/shop/node_modules", bytes: 9),
            CleanupEntry(path: "/u/code/api/.next", bytes: 5),
            CleanupEntry(path: "/u/code/site/node_modules", bytes: 1)
        ]).preview()
        #expect(preview == "shop/node_modules, .next, blog/node_modules and 1 more")
    }

    @Test func aShortListHasNoRemainder() {
        let preview = item([CleanupEntry(path: "/u/Library/Caches/com.example", bytes: 3, name: "Example")]).preview()
        #expect(preview == "Example")
    }
}
