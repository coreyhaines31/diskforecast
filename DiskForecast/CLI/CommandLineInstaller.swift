import Foundation

/// Links the bundled `diskforecast` command onto the PATH, for people who didn't install with Homebrew.
enum CommandLineInstaller {
    private static let homebrew = "/opt/homebrew/bin"
    private static let system = "/usr/local/bin"

    /// What to paste into Claude Code or Codex, or a CLAUDE.md or AGENTS.md, so an agent uses the command well.
    static let agentPrompt = """
        When my Mac is low on disk space, use the `diskforecast` command (run `diskforecast --help`). Start with \
        `diskforecast status` and `diskforecast changes --days 30` to explain what's filling the disk, then \
        `diskforecast cleanup` to see what can be reclaimed. Show me what you'd move and ask before running \
        `diskforecast trash <id> --yes`. Never delete files directly.
        """

    private static var tool: String? {
        Bundle.main.url(forAuxiliaryExecutable: "diskforecast")?.path
    }

    /// Where the command is linked onto the PATH, or nil if it isn't.
    static var installedPath: String? {
        guard let tool, let real = realPath(tool) else { return nil }
        return [homebrew, system].map { "\($0)/diskforecast" }.first { realPath($0) == real }
    }

    /// Installs the link and describes what happened.
    static func install() -> String {
        guard let tool else {
            return "This copy of Disk Forecast doesn't include the command. "
                + "Download the latest version from diskforecast.com."
        }
        if let installedPath {
            return "The diskforecast command is already installed at \(installedPath)."
        }
        let manager = FileManager.default
        if manager.isWritableFile(atPath: homebrew) {
            let link = "\(homebrew)/diskforecast"
            if manager.fileExists(atPath: link) || destination(link) != nil {
                guard destination(link)?.hasSuffix("/Contents/MacOS/diskforecast") == true else {
                    return "Something else is already installed at \(link), so Disk Forecast left it alone."
                }
                try? manager.removeItem(atPath: link)
            }
            do {
                try manager.createSymbolicLink(atPath: link, withDestinationPath: tool)
                return "Installed the diskforecast command at \(link). Open a new Terminal window to use it."
            } catch {
                return "Couldn't install the diskforecast command: \(error.localizedDescription)"
            }
        }
        let link = "\(system)/diskforecast"
        if manager.fileExists(atPath: link), destination(link) == nil {
            return "Something else is already installed at \(link), so Disk Forecast left it alone."
        }
        // /usr/local/bin needs an administrator, so macOS asks for a password.
        let command = "mkdir -p \(system) && ln -sfn \(shellQuoted(tool)) \(link)"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?
            .executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "unknown error"
            return (error[NSAppleScript.errorNumber] as? Int) == -128
                ? "Didn't install the diskforecast command."
                : "Couldn't install the diskforecast command: \(message)"
        }
        return "Installed the diskforecast command at \(link). Open a new Terminal window to use it."
    }

    /// Where a symbolic link points, or nil if the path isn't one.
    private static func destination(_ path: String) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: path)
    }

    /// The path with every link resolved, or nil if nothing is there.
    private static func realPath(_ path: String) -> String? {
        guard let real = realpath(path, nil) else { return nil }
        defer { free(real) }
        return String(cString: real)
    }

    private static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
