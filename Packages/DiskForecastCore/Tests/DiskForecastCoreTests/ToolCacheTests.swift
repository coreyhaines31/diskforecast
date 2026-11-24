@testable import DiskForecastCore
import Foundation
import Testing

struct ToolCacheTests {
    @Test func showsTheCommandItRuns() {
        let commands = ToolCache.all.map(\.command)
        #expect(commands == [
            "pnpm store prune", "uv cache prune", "go clean -modcache", "go clean -cache",
            "brew cleanup --prune=all"
        ])
    }

    @Test func saysWhetherItPrunesOrClears() {
        let kinds = Dictionary(uniqueKeysWithValues: ToolCache.all.map { ($0.id, $0.kind) })
        #expect(kinds["pnpm-store"] == .prune)
        #expect(kinds["uv-cache"] == .prune)
        #expect(kinds["go-modules"] == .clear)
        #expect(ToolCache.all[0].kindNote == "prunes what nothing uses")
    }

    @Test func readsThePathATookPrinted() {
        #expect(ToolCache.path(fromOutput: "/Users/me/Library/pnpm/store/v11\n") == "/Users/me/Library/pnpm/store/v11")
        // A notice ahead of the answer.
        #expect(ToolCache.path(fromOutput: "Update available!\n  /Users/me/go/pkg/mod  \n") == "/Users/me/go/pkg/mod")
        #expect(ToolCache.path(fromOutput: "command not found") == nil)
        #expect(ToolCache.path(fromOutput: "/") == nil)
        #expect(ToolCache.path(fromOutput: "") == nil)
    }

    @Test func looksForToolsWhereTheyGetInstalled() {
        let installed: Set<String> = ["/Users/me/.nvm/versions/node/v22.23.4/bin/pnpm", "/opt/homebrew/bin/uv"]
        let folders = ToolCache.searchFolders(home: "/Users/me", nodeVersions: ["v18.20.0", "v22.23.4", "v9.1.0"])
        #expect(folders.last == "/Users/me/.nvm/versions/node/v22.23.4/bin")
        #expect(folders.map { $0 + "/pnpm" }.first(where: installed.contains)
            == "/Users/me/.nvm/versions/node/v22.23.4/bin/pnpm")
        #expect(ToolCache.executable(named: "uv", home: "/Users/me", isExecutable: installed.contains)
            == "/opt/homebrew/bin/uv")
        #expect(ToolCache.executable(named: "zig", home: "/Users/me", isExecutable: installed.contains) == nil)
    }
}
