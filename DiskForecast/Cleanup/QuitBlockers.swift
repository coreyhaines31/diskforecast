import AppKit
import DiskForecastCore

/// Quits the apps and ends the Claude Code sessions that kept cleanup items in place, after naming
/// each one, so those items can be tried again.
@MainActor
enum QuitBlockers {
    struct Plan {
        let apps: [(name: String, bundle: String)]
        let sessions: [OpenFiles.Program]
        var isEmpty: Bool { apps.isEmpty && sessions.isEmpty }
    }

    /// Apps by their bundle, never the system's own or Disk Forecast, and Claude Code sessions.
    /// Anything else, like a shell or a server, is left for the person to stop.
    static func plan(_ blockers: [OpenFiles.Program]) -> Plan {
        let sessions = blockers.filter { $0.name == OpenFiles.claudeCode && $0.pid > 0 }
        var apps: [(name: String, bundle: String)] = []
        for program in blockers where program.name != OpenFiles.claudeCode {
            guard let bundle = program.bundle, !bundle.hasPrefix("/System/"), bundle != Bundle.main.bundlePath,
                  !apps.contains(where: { $0.bundle == bundle }) else { continue }
            apps.append((program.name, bundle))
        }
        return Plan(apps: apps, sessions: sessions)
    }

    static func confirm(_ plan: Plan, trasher: Trasher, retrying count: Int) -> Bool {
        var actions: [String] = []
        if !plan.apps.isEmpty { actions.append("quit " + plan.apps.map(\.name).formatted(.list(type: .and))) }
        if !plan.sessions.isEmpty {
            actions.append("end " + (plan.sessions.count == 1
                ? "1 Claude Code session" : "\(plan.sessions.count) Claude Code sessions"))
        }
        let question = actions.joined(separator: " and ")
        var text: [String] = []
        if !plan.apps.isEmpty {
            text.append("Apps quit the usual way, so one with unsaved work asks first.")
        }
        if !plan.sessions.isEmpty {
            let sessions = trasher.describe(plan.sessions, limit: 6).formatted(.list(type: .and))
            text.append("Claude Code sessions: " + sessions + ". Anything they're in the middle of stops. Each "
                + "conversation is saved, so you can pick it up again with claude --resume.")
        }
        text.append("Then Disk Forecast tries the \(count == 1 ? "item" : "\(count) items") again.")
        let alert = NSAlert()
        alert.messageText = question.prefix(1).uppercased() + question.dropFirst() + "?"
        alert.informativeText = text.joined(separator: "\n\n")
        alert.addButton(withTitle: "Quit and Try Again").hasDestructiveAction = !plan.sessions.isEmpty
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Asks each to stop, then waits up to 15 seconds for them to go.
    static func quit(_ plan: Plan) async {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            plan.apps.contains { $0.bundle == app.bundleURL?.path }
        }
        apps.forEach { $0.terminate() }
        // The process ID could belong to something new by now, so only signal it if it's still Claude Code.
        let sessions = plan.sessions.map(\.pid).filter(OpenFiles.isClaudeCode)
        sessions.forEach { kill($0, SIGTERM) }
        for _ in 0..<30 {
            if apps.allSatisfy(\.isTerminated) && sessions.allSatisfy({ kill($0, 0) != 0 }) { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
