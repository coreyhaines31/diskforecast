@testable import DiskForecastCore
import Foundation
import Testing

/// Builds a stand-in for the user's temp folder under the test run's own folder, so nothing here
/// ever reads or moves the real one.
struct UserTempTests {
    let home: URL
    let temp: URL
    let now = Date()
    var old: Date { now.addingTimeInterval(-5 * 86_400) }

    init() throws {
        let made = TestFolders.make("UserTemp")
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        let base = URL(filePath: Trasher.resolved(made.path))
        home = base.appending(path: "home")
        temp = base.appending(path: "T")
        for folder in [home, temp] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    /// Writes a file and dates it and every folder above it, up to the temp folder.
    private func write(_ relative: String, bytes: Int, modified: Date) throws {
        let url = temp.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        var path = url.path
        while path != temp.path {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: path)
            path = (path as NSString).deletingLastPathComponent
        }
    }

    private func entries() async -> [CleanupEntry] {
        let homeScan = await DiskScanner(options: .init(root: home)).scan()
        let tempScan = await DiskScanner(options: .init(root: temp)).scan()
        let items = CleanupCatalog(home: home.path, now: now, userTemp: tempScan).items(from: homeScan)
        let item = items.first { $0.id == "temp-files" }
        #expect(item.map { $0.group == .safeToClear } ?? true)
        return item?.entries ?? []
    }

    @Test func listsWhatNothingHasChangedInThreeDays() async throws {
        try write("old-folder/blob", bytes: 2_000_000, modified: old)
        try write("old-file.bin", bytes: 2_000_000, modified: old)
        try write("busy-folder/blob", bytes: 2_000_000, modified: old)
        // Something running is still writing into it, though the folder itself looks old.
        try write("busy-folder/log", bytes: 10, modified: now)
        try write("recent/blob", bytes: 2_000_000, modified: now)
        try write("old-small/blob", bytes: 10, modified: old)

        let entries = await entries()
        #expect(Set(entries.map(\.path)) == [temp.path + "/old-folder", temp.path + "/old-file.bin"])
        #expect(entries.allSatisfy { $0.detail == "Last changed 5 days ago" })
        #expect(entries.allSatisfy { $0.bytes >= 2_000_000 })
    }

    @Test func leavesMacOSFilesAndLinksAlone() async throws {
        try write("com.apple.something/blob", bytes: 2_000_000, modified: old)
        let elsewhere = temp.deletingLastPathComponent().appending(path: "C")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try Data(count: 2_000_000).write(to: elsewhere.appending(path: "blob"))
        let link = temp.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: elsewhere)
        let seconds = Int(old.timeIntervalSince1970)
        var times = [timeval(tv_sec: seconds, tv_usec: 0), timeval(tv_sec: seconds, tv_usec: 0)]
        #expect(lutimes(link.path, &times) == 0)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: elsewhere.path)

        #expect(await entries().isEmpty)
    }

    @Test func saysHowManySiblingsShareAName() async throws {
        for index in 0..<12 {
            try write("DiskForecastHome-\(index)/blob", bytes: 1_100_000, modified: old)
        }
        try write("unique/blob", bytes: 2_000_000, modified: old)

        let entries = await entries()
        #expect(entries.count == 13)
        let grouped = entries.filter { $0.name.hasPrefix("DiskForecastHome-") }
        #expect(grouped.allSatisfy { $0.detail == "Last changed 5 days ago · 1 of 12 named DiskForecastHome-…" })
        #expect(entries.first { $0.name == "unique" }?.detail == "Last changed 5 days ago")
    }
}
