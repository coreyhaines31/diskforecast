import AppKit
import SwiftUI

/// Hosts a SwiftUI view in a standard window that's created once and reused.
@MainActor
final class HostedWindow {
    private let title: String
    private let size: NSSize
    private let makeView: () -> AnyView
    private var window: NSWindow?

    init(title: String, size: NSSize, view: @escaping () -> some View) {
        self.title = title
        self.size = size
        self.makeView = { AnyView(view()) }
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: makeView()))
            window.title = title
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.setContentSize(size)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
