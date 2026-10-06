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
}
