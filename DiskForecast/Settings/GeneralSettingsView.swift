import os
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    private static let logger = Logger(subsystem: "app.diskforecast.DiskForecast", category: "Settings")

    let updater: Updater
    @State private var checksForUpdates: Bool
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Preferences.menuBarDisplayKey) private var menuBarDisplay = MenuBarDisplay.freeSpace

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
            }
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
