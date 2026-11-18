import Darwin
@testable import DiskForecastCore
import Foundation
import Testing

struct DuplicateFolderCheckTests {
    let base: URL
    var original: String { base.path + "/Desktop/Trip" }
    var copy: String { base.path + "/Downloads/Trip" }

    init() throws {
        let made = TestFolders.make("DiskForecastDuplicateCheck")
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        base = URL(filePath: Trasher.resolved(made.path))
    }

    /// The three largest files come first, so a change to the small one is one the scan's samples never read.
    private let trip = ["a.bin": 300_000, "photos/b.bin": 200_000, "photos/c.bin": 150_000, "notes.txt": 5_000]

    private func writeTrip(in folders: [String]) throws {
        for (file, bytes) in trip {
            var data = Data(count: bytes)
            data.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, bytes) }
            for folder in folders {
                let url = URL(filePath: folder + "/" + file)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try data.write(to: url)
            }
        }
        for folder in folders {
            try FileManager.default.createSymbolicLink(atPath: folder + "/latest", withDestinationPath: "photos/b.bin")
        }
    }

    /// Changes one byte in place, so the file keeps its length and its space on disk.
    private func flipByte(in path: String, at offset: off_t) {
        let descriptor = open(path, O_RDWR)
        var byte: UInt8 = 0
        _ = pread(descriptor, &byte, 1, offset)
        byte ^= 0xFF
        _ = pwrite(descriptor, &byte, 1, offset)
        close(descriptor)
    }

    @Test func passesIdenticalFolders() throws {
        try writeTrip(in: [original, copy])
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == nil)
    }

    @Test func refusesASmallFileThatChangedButKeptItsLength() throws {
        try writeTrip(in: [original, copy])
        flipByte(in: copy + "/notes.txt", at: 4_000)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
    }

    @Test func refusesAMissingFile() throws {
        try writeTrip(in: [original, copy])
        try FileManager.default.removeItem(atPath: original + "/notes.txt")
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
    }

    @Test func refusesAnExtraFileOrFolder() throws {
        try writeTrip(in: [original, copy])
        try Data(count: 10).write(to: URL(filePath: copy + "/photos/extra.txt"))
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
        try FileManager.default.removeItem(atPath: copy + "/photos/extra.txt")
        try FileManager.default.createDirectory(atPath: copy + "/empty", withIntermediateDirectories: false)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
    }

    @Test func refusesALinkThatPointsSomewhereElse() throws {
        try writeTrip(in: [original, copy])
        try FileManager.default.removeItem(atPath: copy + "/latest")
        try FileManager.default.createSymbolicLink(atPath: copy + "/latest", withDestinationPath: "photos/c.bin")
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
    }

    @Test func refusesWhenTheOriginalIsGoneOrNotAFolder() throws {
        try writeTrip(in: [copy])
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .originalMissing)
        // A link left in its place doesn't count, even one that leads back to the copy.
        try FileManager.default.createDirectory(atPath: base.path + "/Desktop", withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: original, withDestinationPath: copy)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .originalMissing)
    }

    @Test func refusesComparingAFolderWithItself() throws {
        try writeTrip(in: [copy])
        #expect(DuplicateFolders.mismatch(of: copy, with: copy) == .incomplete)
        #expect(DuplicateFolders.mismatch(of: copy + "/photos", with: copy) == .incomplete)
    }

    @Test func passesClonesAndReadsThemLikeAnyOtherFile() throws {
        try writeTrip(in: [original])
        try FileManager.default.createDirectory(atPath: base.path + "/Downloads", withIntermediateDirectories: true)
        try #require(clonefile(original, copy, 0) == 0)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == nil)
        // Unreadable, so the check can't finish: a clone is read, not taken on the file system's word.
        chmod(copy + "/a.bin", 0)
        defer { chmod(copy + "/a.bin", 0o644) }
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .incomplete)
    }

    @Test func refusesACloneThatWasChangedAfterward() throws {
        try writeTrip(in: [original])
        try FileManager.default.createDirectory(atPath: base.path + "/Downloads", withIntermediateDirectories: true)
        try #require(clonefile(original, copy, 0) == 0)
        flipByte(in: copy + "/notes.txt", at: 10)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .differs)
    }

    @Test func passesHardLinksWithoutReadingThem() throws {
        try writeTrip(in: [original, copy])
        try FileManager.default.removeItem(atPath: copy + "/a.bin")
        try FileManager.default.linkItem(atPath: original + "/a.bin", toPath: copy + "/a.bin")
        chmod(original + "/a.bin", 0)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == nil)
        chmod(original + "/a.bin", 0o644)
    }

    @Test func refusesWhatCantBeRead() throws {
        try writeTrip(in: [original, copy])
        chmod(copy + "/notes.txt", 0)
        #expect(DuplicateFolders.mismatch(of: copy, with: original) == .incomplete)
        chmod(copy + "/notes.txt", 0o644)
    }

    @Test func trashKeepsACopyThatNoLongerMatches() throws {
        try writeTrip(in: [original, copy])
        flipByte(in: copy + "/notes.txt", at: 0)
        let entry = CleanupEntry(path: copy, bytes: 655_000, original: original)
        for permanently in [false, true] {
            let report = Trasher(home: base.path).trash([entry], permanently: permanently)
            #expect(report.moved.isEmpty)
            #expect(report.failureLines() == [
                "• Downloads/Trip: It isn't the same as ~/Desktop/Trip any more, so it stays."
            ])
            #expect(FileManager.default.fileExists(atPath: copy))
        }
    }

    @Test func trashMovesACopyThatStillMatches() throws {
        try writeTrip(in: [original, copy])
        let entry = CleanupEntry(path: copy, bytes: 655_000, original: original)
        let report = Trasher(home: base.path).trash([entry])
        #expect(report.moved == [copy])
        #expect(FileManager.default.fileExists(atPath: original))
        if let trashed = report.inTrash[copy] { try? FileManager.default.removeItem(atPath: trashed) }
    }

    @Test func namesTheOriginalFromHome() {
        #expect(DuplicateFolders.Mismatch.originalMissing.reason(comparedWith: "~/Desktop/Trip")
            == "~/Desktop/Trip, the folder it matched, is gone or has moved, so it stays.")
    }
}
