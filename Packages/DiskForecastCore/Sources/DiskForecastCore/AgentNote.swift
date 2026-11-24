import Foundation

/// A short note in a coding agent's global instructions file, so the agent knows the `diskforecast`
/// command is there. The install prompt in the README asks agents to write the same text, so there's
/// one note to find and remove whichever way it was added.
public enum AgentNote {
    public static let text = """
        ## Disk space
        Disk Forecast is installed. For disk questions, or on "No space left on device", run \
        `diskforecast status`, then `diskforecast cleanup` (see `diskforecast --help`; if it isn't on the PATH, \
        it's at "/Applications/Disk Forecast.app/Contents/MacOS/diskforecast"). Only move things to the Trash \
        when I say so.
        """

    public enum State: Equatable, Sendable {
        /// The tool's folder isn't there, so the tool isn't installed.
        case toolNotFound
        case notAdded
        case added
    }

    public enum NoteError: LocalizedError {
        case noFolder(String)
        case notText(String)

        public var errorDescription: String? {
            switch self {
            case .noFolder(let path): "There's no \(path) folder, so Disk Forecast didn't create one."
            case .notText(let path): "\(path) isn't plain text, so Disk Forecast left it alone."
            }
        }
    }

    /// The instruction files Disk Forecast offers to add the note to.
    public static func targets(home: URL) -> [(tool: String, file: URL)] {
        [
            ("Claude Code", home.appending(path: ".claude/CLAUDE.md")),
            ("Codex", home.appending(path: ".codex/AGENTS.md"))
        ]
    }

    public static func isPresent(in contents: String) -> Bool {
        noteRange(in: Array(contents.utf8)) != nil
    }

    /// The contents with the note added at the end after a blank line, or unchanged if it's there.
    public static func appended(to contents: String) -> String {
        contents + addition(to: contents)
    }

    /// The contents with the note taken out, along with the blank line `appended(to:)` put before it.
    /// Everything else stays as it was, including text written before or after the note since.
    public static func removed(from contents: String) -> String {
        var bytes = Array(contents.utf8)
        while let range = noteRange(in: bytes) {
            var before = Array(bytes[..<range.lowerBound])
            var after = Array(bytes[range.upperBound...])
            if after.first == newline { after.removeFirst() }
            if before.suffix(2) == [newline, newline] {
                before.removeLast()
            } else if before.isEmpty, after.first == newline {
                after.removeFirst()
            }
            bytes = before + after
        }
        // Only whole ASCII newlines and the note's own bytes are cut, so the result is still UTF-8.
        return String(bytes: bytes, encoding: .utf8) ?? contents
    }

    public static func state(of file: URL) -> State {
        guard isFolder(file.deletingLastPathComponent()) else { return .toolNotFound }
        guard let contents = try? read(file) else { return .notAdded }
        return isPresent(in: contents) ? .added : .notAdded
    }

    /// Adds the note at the end of the file, writing only the new text. Creates the file if its
    /// folder is there, but never the folder.
    public static func add(to file: URL) throws {
        let folder = file.deletingLastPathComponent()
        guard isFolder(folder) else { throw NoteError.noFolder(folder.path) }
        let addition = addition(to: try read(file) ?? "")
        guard !addition.isEmpty else { return }
        if !FileManager.default.fileExists(atPath: file.path) {
            try Data().write(to: file)
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(addition.utf8))
    }

    /// Takes the note out of the file, if it's there.
    public static func remove(from file: URL) throws {
        guard let contents = try read(file) else { return }
        let result = removed(from: contents)
        guard result != contents else { return }
        // Write to the file a link points to, so a CLAUDE.md linked from a dotfiles folder stays a link.
        let real = file.resolvingSymlinksInPath()
        let folder = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: real, create: true
        )
        defer { try? FileManager.default.removeItem(at: folder) }
        let replacement = folder.appending(path: real.lastPathComponent)
        try Data(result.utf8).write(to: replacement)
        // Swaps the new text in whole, and keeps the file's permissions and extended attributes.
        _ = try FileManager.default.replaceItemAt(real, withItemAt: replacement)
    }

    private static let newline = UInt8(ascii: "\n")

    /// What `appended(to:)` adds: a blank line unless there is one, the note, and a final newline.
    private static func addition(to contents: String) -> String {
        guard !isPresent(in: contents) else { return "" }
        let bytes = Array(contents.utf8)
        let separator = if bytes.isEmpty || bytes.suffix(2) == [newline, newline] {
            ""
        } else if bytes.last == newline {
            "\n"
        } else {
            "\n\n"
        }
        return separator + text + "\n"
    }

    /// Where the note sits on lines of its own, or nil if it isn't there word for word.
    private static func noteRange(in bytes: [UInt8]) -> Range<Int>? {
        let note = Array(text.utf8)
        guard bytes.count >= note.count else { return nil }
        for start in 0...(bytes.count - note.count) where bytes[start] == note[0] {
            let end = start + note.count
            guard bytes[start..<end].elementsEqual(note) else { continue }
            let startsLine = start == 0 || bytes[start - 1] == newline
            let endsLine = end == bytes.count || bytes[end] == newline || bytes[end] == UInt8(ascii: "\r")
            if startsLine, endsLine { return start..<end }
        }
        return nil
    }

    /// The file's text, or nil if there's no file.
    private static func read(_ file: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        guard let text = String(data: try Data(contentsOf: file), encoding: .utf8) else {
            throw NoteError.notText(file.path)
        }
        return text
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
