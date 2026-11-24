import Foundation

/// Where tests make their folders: one folder per test run, removed when the run ends. Tests used
/// to make theirs straight in the temporary folder and leave them there, which added up to
/// thousands of folders and several gigabytes.
enum TestFolders {
    static let root: URL = {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DiskForecastTests-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        atexit { try? FileManager.default.removeItem(at: TestFolders.root) }
        return url
    }()

    /// A path for a new folder or file that nothing else in this run uses. Not created.
    static func make(_ name: String) -> URL {
        root.appending(path: "\(name)-\(UUID().uuidString)")
    }
}
