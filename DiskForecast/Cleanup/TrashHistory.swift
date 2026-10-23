import DiskForecastCore

/// The last trash run, from the Cleanup window, the menu, or the `diskforecast` command, so
/// either one can undo it. Kept only while the app is running.
@MainActor
enum TrashHistory {
    private static var last: (report: Trasher.Report, trasher: Trasher)?

    static var canUndo: Bool { last != nil }

    static func record(_ report: Trasher.Report, trasher: Trasher) {
        last = report.moved.isEmpty ? nil : (report, trasher)
    }

    /// Forgets the last run once the Trash is emptied, since nothing can go back.
    static func clear() {
        last = nil
    }

    /// Puts back what the last run moved. Nil when there's nothing to undo.
    static func undo() -> (report: Trasher.Report, failed: [(path: String, reason: String)])? {
        guard let last else { return nil }
        self.last = nil
        return (last.report, last.trasher.putBack(last.report))
    }
}
