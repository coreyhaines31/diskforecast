import DiskForecastCore
import Foundation

let usage = """
diskforecast: check when your Mac's disk will be full, see what's filling it, and reclaim space, from \
the terminal.

Usage:
  diskforecast status [--json]
  diskforecast changes [--days 7] [--json]
  diskforecast cleanup [--json]
  diskforecast scan [--wait] [--json]
  diskforecast trash <id or path>... [--yes] [--json]
  diskforecast open forecast|cleanup|system-data|settings

Commands:
  status    Free space, the forecast, and how much is safe to clear.
  changes   Which folders grew or shrank over the last 7 days (or --days N), and by how much.
  cleanup   What you can reclaim, with an ID for each item and why it's safe or worth a look.
  scan      Measure the home folder again. --wait waits for the scan to finish.
  trash     Move cleanup items (by ID) or entries (by path) to the Trash. Without --yes it
            only shows what it would move. Only what's on the cleanup list can be moved,
            and nothing is deleted: you can put it all back until you empty the Trash.
  open      Show one of Disk Forecast's windows.

Examples:
  diskforecast changes --days 30
  diskforecast trash xcode-derived-data package-caches --yes
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("diskforecast: \(message)\n".utf8))
    exit(1)
}

func note(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// Sends one request and reads the reply. Nil if the app isn't listening.
func send(_ request: CLIRequest) -> CLIResponse? {
    let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket >= 0 else { return nil }
    defer { close(socket) }
    setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, [Int32(1)], socklen_t(MemoryLayout<Int32>.size))
    // Moving many things to the Trash can take a while; a stuck app still can't hold this up forever.
    var timeout = timeval(tv_sec: 60, tv_usec: 0)
    setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    guard var address = socketAddress() else { fail("The path to Disk Forecast's socket is too long.") }
    let size = socklen_t(MemoryLayout<sockaddr_un>.size)
    let connected = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socket, $0, size) }
    }
    guard connected == 0, let body = try? CLIProtocol.encoder().encode(request) else { return nil }
    let sent = body.withUnsafeBytes { write(socket, $0.baseAddress, $0.count) }
    guard sent == body.count else { return nil }
    shutdown(socket, SHUT_WR)
    var reply = Data()
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while true {
        let received = read(socket, &buffer, buffer.count)
        if received < 0, errno == EINTR { continue }
        if received <= 0 { break }
        reply.append(buffer, count: received)
    }
    return try? CLIProtocol.decoder().decode(CLIResponse.self, from: reply)
}

func socketAddress() -> sockaddr_un? {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(CLIProtocol.socketURL.path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
    return address
}

/// The app this command ships inside, or nil when it was built on its own.
func enclosingApp() -> URL? {
    // argv[0] is just "diskforecast" when found on the PATH, so ask for the real path.
    guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return app.pathExtension == "app" ? app : nil
}

/// Opens Disk Forecast in the background if needed, then sends the request.
func sendLaunchingApp(_ request: CLIRequest) -> CLIResponse {
    if let response = send(request) { return response }
    let open = Process()
    open.executableURL = URL(filePath: "/usr/bin/open")
    open.arguments = enclosingApp().map { ["-g", $0.path] } ?? ["-g", "-b", CLIProtocol.bundleIdentifier]
    open.standardError = FileHandle.nullDevice
    do {
        try open.run()
        open.waitUntilExit()
    } catch {
        fail("Couldn't open Disk Forecast: \(error.localizedDescription)")
    }
    guard open.terminationStatus == 0 else {
        fail("Couldn't find Disk Forecast. Install it with: brew install --cask coreyhaines31/tap/diskforecast")
    }
    for _ in 0..<50 {
        Thread.sleep(forTimeInterval: 0.2)
        if let response = send(request) { return response }
    }
    fail("Disk Forecast opened but didn't answer. Check that it's running in the menu bar.")
}

/// "~/code/api" for paths in the home folder.
func shortened(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
}

func signed(_ bytes: Int64) -> String {
    (bytes >= 0 ? "+" : "-") + Bytes.format(abs(bytes))
}

func describe(_ status: CLIStatus) -> String {
    let percent = status.capacityBytes > 0
        ? Int((Double(status.freeBytes) / Double(status.capacityBytes) * 100).rounded()) : 0
    var lines = [
        "\(Bytes.format(status.freeBytes)) free of \(Bytes.format(status.capacityBytes)) (\(percent)% free)",
        status.forecast
    ]
    if status.lowOnSpace { lines.append("Low on space.") }
    if status.scanning {
        lines.append("Measuring your home folder now.")
    } else if status.safeToClearBytes > 0 {
        lines.append("Safe to clear: \(Bytes.format(status.safeToClearBytes)). See it with: diskforecast cleanup")
    }
    if let lastScan = status.lastScan, !status.scanning {
        lines.append("Last measured \(lastScan.formatted(.relative(presentation: .named))).")
    }
    return lines.joined(separator: "\n")
}

func describe(_ changes: CLIChanges) -> String {
    let format = Date.FormatStyle().month(.abbreviated).day()
    var lines = ["What changed from \(changes.since.formatted(format)) to \(changes.until.formatted(format)):"]
    func add(_ folders: [CLIFolderChange], depth: Int) {
        for folder in folders {
            let name = depth == 0 ? "~/" + folder.path : (folder.path as NSString).lastPathComponent
            let new = folder.oldBytes == 0 ? " (new)" : folder.newBytes == 0 ? " (gone)" : ""
            let size = signed(folder.delta).padding(toLength: 9, withPad: " ", startingAt: 0)
            lines.append(String(repeating: "  ", count: depth + 1) + size + " " + name + new)
            add(folder.children, depth: depth + 1)
        }
    }
    add(changes.folders, depth: 0)
    if abs(changes.outsideHomeBytes) >= 1_000_000_000 {
        let size = signed(changes.outsideHomeBytes).padding(toLength: 9, withPad: " ", startingAt: 0)
        lines.append("  \(size) Outside your home folder (System Data, other accounts, and apps)")
    }
    if lines.count == 1 { lines.append("  No folder changed by more than 500 MB.") }
    return lines.joined(separator: "\n")
}

func describe(_ items: [CLICleanupItem]) -> String {
    guard !items.isEmpty else { return "Nothing to reclaim right now." }
    var lines: [String] = []
    for (group, title) in [("safeToClear", "Safe to clear"), ("worthALook", "Worth a look")] {
        let members = items.filter { $0.group == group }
        guard !members.isEmpty else { continue }
        if !lines.isEmpty { lines.append("") }
        lines.append("\(title): \(Bytes.format(members.reduce(0) { $0 + $1.bytes }))")
        for item in members {
            lines.append("")
            lines.append("  \(item.title) · \(Bytes.format(item.bytes)) · id: \(item.id)")
            lines.append("  \(item.explanation)")
            if let tool = item.tool { lines.append("  Reclaim this with \(tool)'s own command, not the Trash.") }
            for entry in item.entries.prefix(10) {
                let detail = entry.detail.map { " (\($0))" } ?? ""
                lines.append("    \(Bytes.format(entry.bytes).padding(toLength: 8, withPad: " ", startingAt: 0)) "
                    + shortened(entry.path) + detail)
            }
            if item.entries.count > 10 { lines.append("    …and \(item.entries.count - 10) more (see --json)") }
        }
    }
    lines.append("")
    lines.append("Move an item to the Trash with: diskforecast trash <id> --yes")
    return lines.joined(separator: "\n")
}

func describe(_ report: CLITrashReport) -> String {
    var lines: [String] = []
    if report.confirmed {
        lines.append(report.paths.isEmpty
            ? "Nothing was moved to the Trash."
            : "Moved \(Bytes.format(report.bytes)) to the Trash. Empty the Trash to reclaim the space.")
    } else {
        lines.append("Would move \(Bytes.format(report.bytes)) to the Trash:")
    }
    lines += report.paths.map { "  " + shortened($0) }
    if !report.failed.isEmpty {
        lines.append("Couldn't move \(report.failed.count):")
        lines += report.failed.map { "  \(shortened($0.path)): \($0.reason)" }
    }
    if !report.confirmed { lines.append("Run it again with --yes to move them.") }
    return lines.joined(separator: "\n")
}

func printJSON(_ response: CLIResponse) {
    let encoder = CLIProtocol.encoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    print((try? encoder.encode(response)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}")
}

/// Prints the outcome, and returns false for an error.
@discardableResult
func report(_ response: CLIResponse, json asJSON: Bool) -> Bool {
    if let error = response.error {
        if asJSON { printJSON(response) }
        FileHandle.standardError.write(Data("diskforecast: \(error)\n".utf8))
        return false
    }
    if asJSON {
        printJSON(response)
        return response.trash?.failed.isEmpty ?? true
    }
    response.notes.forEach(note)
    var sections: [String] = []
    if let status = response.status { sections.append(describe(status)) }
    if let changes = response.changes { sections.append(describe(changes)) }
    if let cleanup = response.cleanup { sections.append(describe(cleanup)) }
    if let trash = response.trash { sections.append(describe(trash)) }
    if !sections.isEmpty { print(sections.joined(separator: "\n\n")) }
    // Anything that couldn't be moved counts as a failure, so scripts notice.
    return response.trash?.failed.isEmpty ?? true
}

/// Polls until the scan finishes, showing progress on stderr.
func waitForScan(json asJSON: Bool) -> CLIResponse {
    if !asJSON { note("Measuring your home folder. This usually takes under a minute.") }
    while true {
        Thread.sleep(forTimeInterval: 1)
        guard let response = send(CLIRequest(action: .status)) else {
            fail("Disk Forecast stopped answering during the scan.")
        }
        if response.error != nil || response.status?.scanning != true { return response }
    }
}

let command: CLICommand
do {
    command = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail("\(error.message)\nRun diskforecast --help for usage.")
}

switch command {
case .help:
    print(usage)
case .version:
    print(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
case .send(let request, let json, let wait):
    var response = sendLaunchingApp(request)
    if request.action == .scan, response.error == nil {
        if wait {
            if response.status?.scanning == true { response = waitForScan(json: json) }
        } else if !json {
            note("Measuring your home folder. Run diskforecast status to see when it's done.")
            response.status = nil
        }
    }
    if !report(response, json: json) { exit(1) }
}
