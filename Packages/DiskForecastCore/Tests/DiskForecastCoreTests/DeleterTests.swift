@testable import DiskForecastCore
import Foundation
import Testing

struct DeleterTests {
    let home: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "DiskForecastDelete-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        home = URL(filePath: Trasher.resolved(base.path))
    }

    private func write(_ relativePath: String, bytes: Int = 10) throws {
        let url = home.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    /// Nests folders through open handles until the full path is longer than macOS allows.
    private func makeDeepFolder(at path: String) {
        mkdir(path, 0o755)
        var folder = open(path, O_RDONLY)
        let name = String(repeating: "x", count: 200)
        for _ in 0..<8 {
            mkdirat(folder, name, 0o755)
            let next = openat(folder, name, O_RDONLY)
            close(folder)
            folder = next
        }
        close(openat(folder, "index.js", O_CREAT | O_WRONLY, 0o644))
        close(folder)
    }

    @Test func deletesPathsTooLongForFinder() throws {
        let deep = home.path + "/freshtree"
        makeDeepFolder(at: deep)
        #expect(throws: (any Error).self) { try FileManager.default.removeItem(atPath: deep) }
        try Deleter.remove(deep)
        #expect(!FileManager.default.fileExists(atPath: deep))
    }

    @Test func deletesLockedFiles() throws {
        try write("project/locked.txt")
        let locked = home.path + "/project/locked.txt"
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: locked)
        try Deleter.remove(home.path + "/project")
        #expect(!FileManager.default.fileExists(atPath: home.path + "/project"))
    }

    @Test func deletesEntriesWithoutTheTrash() throws {
        try write("code/app/node_modules/pkg/index.js", bytes: 100)
        let path = home.path + "/code/app/node_modules"
        let entry = CleanupEntry(path: path, bytes: 100)
        let report = Trasher(home: home.path).trash([entry], permanently: true, openFiles: OpenFiles(processes: []))
        #expect(report.moved == [path])
        #expect(report.deleted)
        #expect(report.inTrash.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func emptiesTheTrashExceptWhatIsInUse() throws {
        try write(".Trash/node_modules 13-39-28-967/slack-mcp-server")
        try write(".Trash/old cache/blob")
        makeDeepFolder(at: home.path + "/.Trash/freshtree")
        let busy = home.path + "/.Trash/node_modules 13-39-28-967"
        let openFiles = OpenFiles(processes: [(name: "slack-mcp-server", paths: [busy + "/slack-mcp-server"])])

        let report = try TrashBin(home: home.path).empty(openFiles: openFiles)
        #expect(Set(report.moved) == [home.path + "/.Trash/old cache", home.path + "/.Trash/freshtree"])
        #expect(report.failed.map(\.path) == [busy])
        #expect(try TrashBin(home: home.path).contents() == [busy])
    }
}
