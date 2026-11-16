import DiskForecastCore
import Foundation
import Observation

/// What the storage meter remembers between menu rebuilds: the highlighted category, and the
/// Trash it just emptied so its dots can drain out.
@MainActor
@Observable
final class StorageMeterState {
    /// How long the drain runs, from the first dot leaving to the last.
    static let drainDuration: TimeInterval = 1.7
    /// How long the menu keeps saying the Trash was emptied.
    static let emptiedNoteLifetime: TimeInterval = 10 * 60

    /// The category clicked in the legend.
    var pinned: StorageCategory?
    /// The category under the pointer.
    var hovered: StorageCategory?
    private(set) var emptiedBytes: Int64?
    private(set) var emptiedAt: Date?
    private(set) var drainStartedAt: Date?
    /// True while the drain plays, so the meter only redraws every frame then.
    private(set) var isDraining = false

    var highlighted: StorageCategory? { hovered ?? pinned }

    func toggle(_ category: StorageCategory) {
        pinned = pinned == category ? nil : category
    }

    func hover(_ category: StorageCategory, _ inside: Bool) {
        if inside {
            hovered = category
        } else if hovered == category {
            hovered = nil
        }
    }

    func trashEmptied(_ bytes: Int64, at date: Date = Date()) {
        emptiedBytes = bytes
        emptiedAt = date
        drainStartedAt = nil
        if pinned == .trash { pinned = nil }
    }

    /// What the Trash held when it was emptied a few minutes ago, or nil.
    func recentlyEmptied(at date: Date = Date()) -> Int64? {
        guard let emptiedBytes, let emptiedAt, date.timeIntervalSince(emptiedAt) < Self.emptiedNoteLifetime else {
            return nil
        }
        return emptiedBytes
    }

    /// Starts the drain the first time the meter is seen after emptying. With Reduce Motion it
    /// counts as already played.
    func startDrainIfPending(reduceMotion: Bool, at date: Date = Date()) {
        guard recentlyEmptied(at: date) != nil, drainStartedAt == nil else { return }
        drainStartedAt = reduceMotion ? .distantPast : date
        guard !reduceMotion else { return }
        isDraining = true
        Task {
            try? await Task.sleep(for: .seconds(Self.drainDuration))
            isDraining = false
        }
    }

    /// How far the drain has got (0...1), or nil when none is playing.
    func drainProgress(at date: Date) -> Double? {
        guard let drainStartedAt else { return nil }
        let progress = date.timeIntervalSince(drainStartedAt) / Self.drainDuration
        return progress < 1 ? max(0, progress) : nil
    }

    func menuClosed() {
        pinned = nil
        hovered = nil
    }
}
