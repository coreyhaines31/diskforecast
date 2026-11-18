import AppKit
import DiskForecastCore
import os
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    private static let logger = Logger(subsystem: "app.diskforecast.DiskForecast", category: "Settings")

    let updater: Updater
    @State private var checksForUpdates: Bool
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Preferences.menuBarDisplayKey) private var menuBarDisplay = MenuBarDisplay.freeSpace
    @AppStorage(Preferences.storageMeterStyleKey) private var storageMeterStyle = StorageMeterStyle.peak
    @AppStorage(Preferences.notifiesBeforeFullKey) private var notifiesBeforeFull = true
    @State private var commandPath = CommandLineInstaller.installedPath
    @State private var commandNote: String?
    @State private var copiedPrompt = false
    @State private var noteStates: [String: AgentNote.State] = [:]

    init(updater: Updater) {
        self.updater = updater
        _checksForUpdates = State(initialValue: updater.checksAutomatically)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                Picker("Menu bar shows", selection: $menuBarDisplay) {
                    ForEach(MenuBarDisplay.allCases) { Text($0.title).tag($0) }
                }
                Picker("Storage meter", selection: $storageMeterStyle) {
                    ForEach(StorageMeterStyle.allCases) { Text($0.title).tag($0) }
                }
                .help("How the menu shows what's using your disk.")
                Toggle("Notify me before my disk fills", isOn: $notifiesBeforeFull)
                    .help("When the forecast says full within a week, or space runs low. At most once a day.")
            }
            commandLineSection
            Section {
                Toggle("Check for updates automatically", isOn: $checksForUpdates)
                    .onChange(of: checksForUpdates) { _, enabled in updater.checksAutomatically = enabled }
                LabeledContent("Version \(Self.version)") {
                    Button("Check Now") { updater.checkForUpdates() }
                }
            } footer: {
                Text("Update checks are the only thing that goes online. Nothing about your disk ever leaves your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshNotes)
    }

    /// The `diskforecast` command: where it's installed, a way to install it, and the prompt for AI agents.
    private var commandLineSection: some View {
        Section {
            LabeledContent("diskforecast command") {
                if let commandPath {
                    Text("Installed at \(commandPath)").foregroundStyle(.secondary)
                } else {
                    Button("Install…") {
                        commandNote = CommandLineInstaller.install()
                        commandPath = CommandLineInstaller.installedPath
                    }
                }
            }
            LabeledContent("Prompt for AI agents") {
                Button(copiedPrompt ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(CommandLineInstaller.agentPrompt, forType: .string)
                    copiedPrompt = true
                }
            }
            ForEach(Self.noteTargets.indices, id: \.self) { index in
                let target = Self.noteTargets[index]
                LabeledContent {
                    noteControl(tool: target.tool, file: target.file)
                } label: {
                    Text("Note for \(target.tool)")
                    Text(Self.displayPath(target.file))
                }
            }
        } header: {
            Text("Command line")
        } footer: {
            Text(commandNote ?? "Lets you, a script, or an AI agent like Claude Code check the forecast and reclaim "
                + "space from Terminal. Paste the prompt into your agent, or add the note so Claude Code and Codex "
                + "know the command is there.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private static let noteTargets = AgentNote.targets(home: FileManager.default.homeDirectoryForCurrentUser)

    /// Whether the note is in one agent's instructions file, with a button to add or remove it.
    @ViewBuilder
    private func noteControl(tool: String, file: URL) -> some View {
        switch noteStates[tool] ?? AgentNote.state(of: file) {
        case .toolNotFound:
            Text("\(tool) not found").foregroundStyle(.secondary)
        case .notAdded:
            HStack {
                Text("Not added").foregroundStyle(.secondary)
                Button("Add…") { addNote(tool: tool, file: file) }
            }
        case .added:
            HStack {
                Text("Added").foregroundStyle(.secondary)
                Button("Remove") { removeNote(file: file) }
            }
        }
    }

    private func addNote(tool: String, file: URL) {
        let path = Self.displayPath(file)
        let confirm = NSAlert()
        confirm.messageText = "Add this note to \(path)?"
        confirm.informativeText = AgentNote.text + "\n\n"
            + (FileManager.default.fileExists(atPath: file.path)
                ? "It goes at the end of the file. Nothing else in the file changes."
                : "There's no \(file.lastPathComponent) yet, so this creates it.")
            + " New \(tool) sessions read it. Remove takes it out again."
        confirm.addButton(withTitle: "Add Note")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        do {
            try AgentNote.add(to: file)
            commandNote = "Added the note to \(path)."
        } catch {
            commandNote = "Couldn't add the note: \(error.localizedDescription)"
        }
        refreshNotes()
    }

    private func removeNote(file: URL) {
        let path = Self.displayPath(file)
        do {
            try AgentNote.remove(from: file)
            commandNote = "Removed the note from \(path)."
        } catch {
            commandNote = "Couldn't remove the note: \(error.localizedDescription)"
        }
        refreshNotes()
    }

    private func refreshNotes() {
        noteStates = Dictionary(uniqueKeysWithValues: Self.noteTargets.map { ($0.tool, AgentNote.state(of: $0.file)) })
    }

    private static func displayPath(_ file: URL) -> String {
        (file.path as NSString).abbreviatingWithTildeInPath
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("Couldn't change launch at login: \(error.localizedDescription)")
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
