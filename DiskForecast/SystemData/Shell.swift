import Foundation

/// Runs Apple's and other tools' own commands, the only way System Data fixes reclaim space.
enum Shell {
    struct Output: Sendable {
        let status: Int32
        let text: String
        var succeeded: Bool { status == 0 }
    }

    static let searchPath = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"

    static func run(_ executable: String, _ arguments: [String], environment: [String: String] = [:]) async -> Output {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = searchPath
            env.merge(environment) { _, new in new }
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                return Output(status: -1, text: error.localizedDescription)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return Output(status: process.terminationStatus, text: String(bytes: data, encoding: .utf8) ?? "")
        }.value
    }

    /// Runs a shell command as an administrator, after macOS asks for the password.
    static func runAsAdministrator(_ command: String) async -> Output {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return await run("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
    }

    static func quoted(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Where the optional tools live on this Mac, if they're installed.
enum Tools {
    /// A full Xcode, which `simctl` needs; the Command Line Tools alone don't have it.
    static func developerDirectory() async -> String? {
        let selected = await Shell.run("/usr/bin/xcode-select", ["-p"]).text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if selected.contains(".app/") { return selected }
        let fallback = "/Applications/Xcode.app/Contents/Developer"
        return FileManager.default.fileExists(atPath: fallback) ? fallback : nil
    }

    static var docker: String? {
        let candidates = [
            "/usr/local/bin/docker", "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker",
            URL.homeDirectory.appending(path: ".orbstack/bin/docker").path
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
