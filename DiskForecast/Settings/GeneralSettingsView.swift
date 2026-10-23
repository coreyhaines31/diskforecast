import AppKit
import os
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    private static let logger = Logger(subsystem: "app.diskforecast.DiskForecast", category: "Settings")

    let updater: Updater
    @State private var checksForUpdates: Bool
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Preferences.menuBarDisplayKey) private var menuBarDisplay = MenuBarDisplay.freeSpace
    @AppStorage(Preferences.notifiesBeforeFullKey) private var notifiesBeforeFull = true
    @State private var commandPath = CommandLineInstaller.installedPath
    @State private var commandNote: String?
    @State private var copiedPrompt = false

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
        } header: {
            Text("Command line")
        } footer: {
            Text(commandNote ?? "Lets you, a script, or an AI agent like Claude Code check the forecast and reclaim "
                + "space from Terminal. Paste the prompt into your agent, or into CLAUDE.md or AGENTS.md.")
                .font(.caption).foregroundStyle(.secondary)
        }
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
