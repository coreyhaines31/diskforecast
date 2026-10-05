import AppKit
import DiskForecastCore
import Observation

/// One fix for a System Data row, run with the owning tool's own command after confirmation.
struct SystemDataFix: Identifiable {
    let id = UUID()
    let title: String
    /// What happens, shown before anything runs.
    let confirmation: String
    /// The command, shown so nothing runs unseen. Nil for fixes that only open a settings pane.
    let command: String?
    let run: @MainActor () async -> Shell.Output
}

struct SystemDataRow: Identifiable {
    let id: String
    let title: String
    let explanation: String
    var bytes: Int64?
    var sizeNote: String?
    var details: [String] = []
    var fixes: [SystemDataFix] = []
}

/// Explains what macOS lumps into System Data and offers Apple's own tools to reclaim it.
@MainActor
@Observable
final class SystemDataModel {
    private(set) var rows: [SystemDataRow] = []
    private(set) var isLoading = false
    private(set) var runningFix: UUID?
    private let disk: DiskStatus

    init(disk: DiskStatus) {
        self.disk = disk
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            async let snapshots = snapshotsRow()
            async let spotlight = spotlightRow()
            async let simulators = simulatorsRow()
            async let models = appleModelsRow()
            async let docker = dockerRow()
            disk.refresh()
            let loaded = await [purgeableRow(), snapshots, spotlight, simulators, models, docker]
            rows = loaded.compactMap { $0 }
            isLoading = false
        }
    }

    func perform(_ fix: SystemDataFix) {
        let confirm = NSAlert()
        confirm.messageText = fix.title
        confirm.informativeText = fix.confirmation + (fix.command.map { "\n\nRuns: \($0)" } ?? "")
        confirm.addButton(withTitle: fix.command == nil ? "Open" : "Run")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        runningFix = fix.id
        Task {
            let output = await fix.run()
            runningFix = nil
            if !output.succeeded {
                let failed = NSAlert()
                failed.alertStyle = .warning
                failed.messageText = "That didn't finish"
                failed.informativeText = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
                failed.runModal()
            }
            load()
        }
    }

    // MARK: Rows

    private func purgeableRow() -> SystemDataRow {
        SystemDataRow(
            id: "purgeable", title: "Purgeable space",
            explanation: "Space macOS is holding for caches, iCloud copies, and snapshots. It's already counted "
                + "as free, and macOS gives it back on its own when an app needs room.",
            bytes: disk.purgeableBytes
        )
    }

    private func snapshotsRow() async -> SystemDataRow? {
        let output = await Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"])
        guard output.succeeded else { return nil }
        let dates = LocalSnapshots.parse(output.text)
        var row = SystemDataRow(
            id: "snapshots", title: "Local Time Machine snapshots",
            explanation: "Hourly copies Time Machine keeps on this Mac between backups. macOS counts them as purgeable "
                + "and removes them after 24 hours or when space runs low.",
            sizeNote: dates.isEmpty ? "None" : "\(dates.count) snapshot\(dates.count == 1 ? "" : "s")"
        )
        row.details = dates.map { "com.apple.TimeMachine.\($0).local" }
        guard !dates.isEmpty else { return row }
        let command = dates.map { "tmutil deletelocalsnapshots \($0)" }.joined(separator: "; ")
        row.fixes = [SystemDataFix(
            title: "Remove local snapshots",
            confirmation: "Removes the snapshots stored on this Mac. Your Time Machine backups on the backup disk "
                + "aren't touched.",
            command: command
        ) {
            var last = Shell.Output(status: 0, text: "")
            for date in dates {
                last = await Shell.run("/usr/bin/tmutil", ["deletelocalsnapshots", date])
                if !last.succeeded { break }
            }
            return last.succeeded ? last : await Shell.runAsAdministrator(command)
        }]
        return row
    }

    private func spotlightRow() async -> SystemDataRow {
        let path = "/System/Volumes/Data/.Spotlight-V100"
        let result = await DiskScanner(options: .init(root: URL(filePath: path))).scan()
        let measured = result.deniedCount == 0 && result.tree.totalSize > 0
        var row = SystemDataRow(
            id: "spotlight", title: "Spotlight index",
            explanation: "The search index behind Spotlight. It's usually small; when it grows huge, rebuilding it "
                + "often shrinks it. Search results are incomplete while it rebuilds.",
            bytes: measured ? result.tree.totalSize : nil,
            sizeNote: measured ? nil : "Needs administrator access to measure"
        )
        row.fixes = [SystemDataFix(
            title: "Rebuild the Spotlight index",
            confirmation: "Erases the index and lets Spotlight build it again in the background. "
                + "macOS asks for your password.",
            command: "mdutil -E /"
        ) {
            await Shell.runAsAdministrator("/usr/bin/mdutil -E /")
        }]
        return row
    }

    private func simulatorsRow() async -> SystemDataRow? {
        guard let developer = await Tools.developerDirectory() else { return nil }
        let environment = ["DEVELOPER_DIR": developer]
        let xcrun = "/usr/bin/xcrun"
        async let devicesOutput = Shell.run(xcrun, ["simctl", "list", "-j", "devices"], environment: environment)
        async let runtimesOutput = Shell.run(xcrun, ["simctl", "runtime", "list", "-j"], environment: environment)
        let devices = Simulators.parseDevices(Data(await devicesOutput.text.utf8))
        let runtimes = Simulators.parseRuntimes(Data(await runtimesOutput.text.utf8))
        guard !devices.isEmpty || !runtimes.isEmpty else { return nil }

        let deviceBytes = devices.reduce(0) { $0 + $1.dataBytes }
        var row = SystemDataRow(
            id: "simulators", title: "Simulators",
            explanation: "iOS and other simulator runtimes, plus each simulator's apps and data. Xcode downloads a "
                + "runtime again from Settings › Components when you need it.",
            bytes: deviceBytes + runtimes.reduce(0) { $0 + $1.bytes }
        )
        row.details = runtimes.map { "\($0.title) runtime: \(Bytes.format($0.bytes))" }
            + ["\(devices.count) simulators: \(Bytes.format(deviceBytes))"]
        let unavailable = devices.filter { !$0.isAvailable }
        if !unavailable.isEmpty {
            row.fixes.append(SystemDataFix(
                title: "Delete \(unavailable.count) unavailable simulators",
                confirmation: "Deletes simulators whose runtime is no longer installed. They can't run anyway.",
                command: "xcrun simctl delete unavailable"
            ) {
                await Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"], environment: environment)
            })
        }
        for runtime in runtimes where runtime.isDeletable {
            row.fixes.append(SystemDataFix(
                title: "Delete \(runtime.title) (\(Bytes.format(runtime.bytes)))",
                confirmation: "Deletes the \(runtime.title) simulator runtime. Simulators that use it stop working "
                    + "until you download it again in Xcode.",
                command: "xcrun simctl runtime delete \(runtime.identifier)"
            ) {
                await Shell.run(
                    "/usr/bin/xcrun", ["simctl", "runtime", "delete", runtime.identifier], environment: environment
                )
            })
        }
        return row
    }

    private func appleModelsRow() async -> SystemDataRow? {
        let assets = URL(filePath: "/System/Library/AssetsV2")
        let result = await DiskScanner(options: .init(root: assets)).scan()
        let tree = result.tree
        let modelNodes = tree.subdirectories(of: 0).filter {
            (tree.path(of: $0) as NSString).lastPathComponent.hasPrefix("com_apple_MobileAsset_UAF_")
        }
        let bytes = modelNodes.reduce(0) { $0 + tree.size(ofNode: $1) }
        guard bytes > 0 else { return nil }
        var row = SystemDataRow(
            id: "apple-models", title: "Apple Intelligence and Siri models",
            explanation: "On-device models macOS downloads for Apple Intelligence, Siri, dictation, and translation. "
                + "Turning Apple Intelligence off in System Settings removes its models.",
            bytes: bytes
        )
        row.details = modelNodes.prefix(6).map { node in
            let name = (tree.path(of: node) as NSString).lastPathComponent
                .replacingOccurrences(of: "com_apple_MobileAsset_UAF_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            return "\(name): \(Bytes.format(tree.size(ofNode: node)))"
        }
        row.fixes = [SystemDataFix(
            title: "Open Apple Intelligence & Siri settings",
            confirmation: "Opens System Settings, where you can turn Apple Intelligence off.",
            command: nil
        ) {
            let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")
            let opened = url.map { NSWorkspace.shared.open($0) } ?? false
            return Shell.Output(status: opened ? 0 : 1, text: "System Settings didn't open.")
        }]
        return row
    }

    private func dockerRow() async -> SystemDataRow? {
        guard let docker = Tools.docker else { return nil }
        let output = await Shell.run(docker, ["system", "df", "--format", "{{json .}}"])
        let usage = Docker.parse(output.text)
        var row = SystemDataRow(
            id: "docker", title: "Docker",
            explanation: "Images, containers, volumes, and build cache, stored in one disk image. Docker's own "
                + "prune command removes what nothing is using.",
            bytes: usage.isEmpty ? nil : usage.reduce(0) { $0 + $1.bytes },
            sizeNote: output.succeeded ? nil : "Start Docker to measure"
        )
        guard output.succeeded else { return row }
        row.details = usage.map { "\($0.type): \(Bytes.format($0.bytes)), \(Bytes.format($0.reclaimableBytes)) unused" }
        row.fixes = [SystemDataFix(
            title: "Prune unused Docker data",
            confirmation: "Removes stopped containers, unused networks, dangling images, and build cache. "
                + "Running containers, volumes, and tagged images stay.",
            command: "docker system prune -f"
        ) {
            await Shell.run(docker, ["system", "prune", "-f"])
        }]
        return row
    }
}
