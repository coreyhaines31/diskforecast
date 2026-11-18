@testable import DiskForecastCore
import Foundation
import Testing

/// The Trasher's allowance for the user's temp folder, tried on a stand-in under the test run's
/// own folder, never the real one.
struct UserTempTrasherTests {
    let home: URL
    let temp: URL

    init() throws {
        let made = TestFolders.make("UserTempTrash")
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        let base = URL(filePath: Trasher.resolved(made.path))
        home = base.appending(path: "home")
        temp = base.appending(path: "T")
        for folder in [home, temp] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    private func write(_ relative: String) throws {
        let url = temp.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 10).write(to: url)
    }

    @Test func movesWhatsInTheTempFolderButNotTheFolderOrItsNeighbours() throws {
        try write("leftover/blob")
        let neighbour = temp.deletingLastPathComponent().appending(path: "C/cache")
        try FileManager.default.createDirectory(at: neighbour, withIntermediateDirectories: true)
        let scratch = TestFolders.make("claude")
        let trasher = Trasher(home: home.path, agentScratch: scratch.path, userTemp: temp.path)
        let leftover = temp.path + "/leftover"
        #expect(trasher.refusal(for: leftover) == nil)
        #expect(trasher.refusal(for: leftover + "/blob") == nil)
        #expect(trasher.refusal(for: temp.path) == .outsideHome)
        #expect(trasher.refusal(for: temp.path + "/") == .outsideHome)
        #expect(trasher.refusal(for: temp.deletingLastPathComponent().path) == .outsideHome)
        #expect(trasher.refusal(for: neighbour.path) == .outsideHome)
        #expect(trasher.refusal(for: temp.path + "-other") == .outsideHome)
        try write("com.apple.something/blob")
        #expect(trasher.refusal(for: temp.path + "/com.apple.something") == .outsideHome)
        #expect(trasher.refusal(for: temp.path + "/com.apple.something/blob") == .outsideHome)

        let report = trasher.trash([leftover], openFiles: OpenFiles(processes: []))
        #expect(report.moved == [leftover])
        #expect(!FileManager.default.fileExists(atPath: leftover))
        if let trashed = report.inTrash[leftover] { try? FileManager.default.removeItem(atPath: trashed) }
    }

    @Test func leavesTempFilesARunningProgramUses() throws {
        try write("open/blob")
        let open = temp.path + "/open"
        let trasher = Trasher(home: home.path, agentScratch: TestFolders.make("claude").path, userTemp: temp.path)
        let openFiles = OpenFiles(processes: [(name: "Example", paths: [open + "/blob"])])
        let report = trasher.trash([open], openFiles: openFiles)
        #expect(report.moved.isEmpty)
        #expect(FileManager.default.fileExists(atPath: open))
    }

    @Test func stillRefusesEverythingElseOutsideHome() throws {
        let outside = TestFolders.make("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let trasher = Trasher(home: home.path, agentScratch: TestFolders.make("claude").path, userTemp: temp.path)
        #expect(trasher.refusal(for: outside.path) == .outsideHome)
        let report = trasher.trash([outside.path], openFiles: OpenFiles(processes: []))
        #expect(report.moved.isEmpty)
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}
