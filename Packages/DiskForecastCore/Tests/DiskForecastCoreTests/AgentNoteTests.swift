@testable import DiskForecastCore
import Foundation
import Testing

struct AgentNoteTests {
    let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "DiskForecastAgentNote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    private var claude: URL { home.appending(path: ".claude/CLAUDE.md") }

    private func makeClaudeFolder() throws {
        try FileManager.default.createDirectory(
            at: claude.deletingLastPathComponent(), withIntermediateDirectories: true
        )
    }

    private func write(_ text: String) throws {
        try makeClaudeFolder()
        try Data(text.utf8).write(to: claude)
    }

    private func read() throws -> String {
        try text(of: claude)
    }

    private func text(of url: URL) throws -> String {
        String(bytes: try Data(contentsOf: url), encoding: .utf8) ?? ""
    }

    @Test func matchesTheInstallPromptText() {
        #expect(AgentNote.text == """
            ## Disk space
            Disk Forecast is installed. For disk questions, or on "No space left on device", run \
            `diskforecast status`, then `diskforecast cleanup` (see `diskforecast --help`; if it isn't on the PATH, \
            it's at "/Applications/Disk Forecast.app/Contents/MacOS/diskforecast"). Only move things to the Trash \
            when I say so.
            """)
    }

    @Test func targetsClaudeCodeAndCodex() {
        let targets = AgentNote.targets(home: home)
        #expect(targets.map(\.tool) == ["Claude Code", "Codex"])
        #expect(targets.map(\.file) == [
            home.appending(path: ".claude/CLAUDE.md"), home.appending(path: ".codex/AGENTS.md")
        ])
    }

    @Test func appendsAfterABlankLine() {
        #expect(AgentNote.appended(to: "# Mine\n") == "# Mine\n\n" + AgentNote.text + "\n")
        #expect(AgentNote.appended(to: "# Mine\n\n") == "# Mine\n\n" + AgentNote.text + "\n")
        #expect(AgentNote.appended(to: "") == AgentNote.text + "\n")
    }

    @Test func endsALastLineThatHasNoNewline() {
        #expect(AgentNote.appended(to: "# Mine") == "# Mine\n\n" + AgentNote.text + "\n")
    }

    @Test func leavesTheTextAloneWhenTheNoteIsThere() {
        let withNote = "# Mine\n\n" + AgentNote.text + "\n\nMore of mine\n"
        #expect(AgentNote.isPresent(in: withNote))
        #expect(AgentNote.appended(to: withNote) == withNote)
        #expect(AgentNote.isPresent(in: AgentNote.text))
    }

    @Test func doesNotCountAnEditedNote() {
        #expect(!AgentNote.isPresent(in: "# Mine\n"))
        #expect(!AgentNote.isPresent(in: AgentNote.text.replacingOccurrences(of: "Trash", with: "bin")))
        #expect(!AgentNote.isPresent(in: "> " + AgentNote.text + "\n"))
    }

    @Test func removeTakesOutOnlyTheNote() {
        let original = "# Mine\n\nKeep this.\n"
        #expect(AgentNote.removed(from: AgentNote.appended(to: original)) == original)
        #expect(AgentNote.removed(from: AgentNote.appended(to: "")) == "")
        #expect(AgentNote.removed(from: original) == original)
    }

    @Test func removeLeavesTheNewlineThatEndedALastLine() {
        #expect(AgentNote.removed(from: AgentNote.appended(to: "# Mine")) == "# Mine\n")
    }

    @Test func removeKeepsWhatWasWrittenAroundTheNote() {
        let edited = "# Mine\n\n" + AgentNote.text + "\n\n## Added later\nKeep me too.\n"
        #expect(AgentNote.removed(from: edited) == "# Mine\n\n## Added later\nKeep me too.\n")
    }

    @Test func stateNamesAMissingTool() throws {
        #expect(AgentNote.state(of: claude) == .toolNotFound)
        try makeClaudeFolder()
        #expect(AgentNote.state(of: claude) == .notAdded)
        try AgentNote.add(to: claude)
        #expect(AgentNote.state(of: claude) == .added)
    }

    @Test func addDoesNotCreateTheToolsFolder() {
        #expect(throws: (any Error).self) { try AgentNote.add(to: claude) }
        #expect(!FileManager.default.fileExists(atPath: claude.deletingLastPathComponent().path))
    }

    @Test func addCreatesAMissingFileInAnExistingFolder() throws {
        try makeClaudeFolder()
        try AgentNote.add(to: claude)
        #expect(try read() == AgentNote.text + "\n")
    }

    @Test func addKeepsTheFileByteForByte() throws {
        let original = "# Mine\r\n\tTabs and “quotes” ✓"
        try write(original)
        try AgentNote.add(to: claude)
        let bytes = try Data(contentsOf: claude)
        #expect(bytes.starts(with: Data(original.utf8)))
        #expect(try read() == original + "\n\n" + AgentNote.text + "\n")
    }

    @Test func addTwiceAddsOnce() throws {
        try write("# Mine\n")
        try AgentNote.add(to: claude)
        try AgentNote.add(to: claude)
        #expect(try read() == "# Mine\n\n" + AgentNote.text + "\n")
    }

    @Test func removeRestoresTheOriginalBytes() throws {
        let original = "# Mine\n\nKeep this.\n"
        try write(original)
        try AgentNote.add(to: claude)
        try AgentNote.remove(from: claude)
        #expect(try Data(contentsOf: claude) == Data(original.utf8))
    }

    @Test func removeKeepsEditsMadeAfterAdding() throws {
        try write("# Mine\n")
        try AgentNote.add(to: claude)
        let handle = try FileHandle(forWritingTo: claude)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n## Mine later\n".utf8))
        try handle.close()
        try AgentNote.remove(from: claude)
        #expect(try read() == "# Mine\n\n## Mine later\n")
    }

    @Test func removeFromAMissingFileDoesNothing() throws {
        try AgentNote.remove(from: claude)
        #expect(!FileManager.default.fileExists(atPath: claude.deletingLastPathComponent().path))
    }

    @Test func addAndRemoveWriteThroughALinkedFile() throws {
        try makeClaudeFolder()
        let real = home.appending(path: "dotfiles-CLAUDE.md")
        try Data("# Mine\n".utf8).write(to: real)
        try FileManager.default.createSymbolicLink(at: claude, withDestinationURL: real)
        try AgentNote.add(to: claude)
        try AgentNote.remove(from: claude)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: claude.path) == real.path)
        #expect(try text(of: real) == "# Mine\n")
    }
}
