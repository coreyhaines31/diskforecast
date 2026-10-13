#if DEBUG
import AppKit
import DiskForecastCore

/// Runs the app on made-up data for the README images: `--demo --show menu|forecast|cleanup|settings
/// --capture <file>`, plus `--dark` for dark mode (windows only). Scripts/render-readme-images.sh
/// drives it. Debug builds only.
@MainActor
enum DemoMode {
    nonisolated static let isOn = CommandLine.arguments.contains("--demo")
    nonisolated static let supportFolder = FileManager.default.temporaryDirectory.appending(path: "DiskForecastDemo")

    static var show: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--show"),
              index + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// Writes the demo history and folder snapshots where the app will read them.
    static func prepare(home: String) {
        try? FileManager.default.removeItem(at: supportFolder)
        try? Demo.history().save(to: supportFolder.appending(path: "history.json"))
        let store = FolderSnapshotStore(folder: supportFolder.appending(path: "Snapshots"))
        let snapshots = Demo.snapshots(home: home)
        try? store.save(snapshots.old)
        try? store.save(snapshots.new)
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    /// Where to save the capture, from `--capture <file>`.
    static var captureURL: URL? {
        guard let index = CommandLine.arguments.firstIndex(of: "--capture"),
              index + 1 < CommandLine.arguments.count else { return nil }
        return URL(filePath: CommandLine.arguments[index + 1])
    }

    /// Draws one of the app's own windows, title bar included, to a PNG, then quits. An app can
    /// always draw its own windows, so this needs no Screen Recording permission.
    /// - Parameter title: the window to capture, or nil for the open menu.
    static func captureAndQuit(windowTitled title: String?) {
        // Common-mode timers also fire while the menu is open and tracking. The first moves the
        // pointer off the menu, so the capture shows no highlighted item.
        let unhighlight = Timer(timeInterval: 1.0, repeats: false) { _ in
            MainActor.assumeIsolated {
                if let event = NSEvent.mouseEvent(
                    with: .mouseMoved, location: NSPoint(x: 5, y: 5), modifierFlags: [], timestamp: 0,
                    windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
                ) {
                    NSApp.postEvent(event, atStart: false)
                }
            }
        }
        RunLoop.main.add(unhighlight, forMode: .common)
        let timer = Timer(timeInterval: 1.6, repeats: false) { _ in
            MainActor.assumeIsolated {
                if let url = captureURL,
                   let window = NSApp.windows.first(where: { $0.isVisible && isTarget($0, title: title) }),
                   let view = window.contentView?.superview ?? window.contentView,
                   let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: url)
                }
                exit(0)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func isTarget(_ window: NSWindow, title: String?) -> Bool {
        guard let title else { return String(describing: type(of: window)).contains("Menu") }
        return window.title == title
    }
}
#endif
