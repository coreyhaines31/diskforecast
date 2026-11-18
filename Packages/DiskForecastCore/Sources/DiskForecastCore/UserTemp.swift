import Foundation

/// The user's own temp folder, $TMPDIR, under /private/var/folders. Apps, scripts, and test runs
/// make folders there and often never remove them.
public enum UserTemp {
    /// With links resolved, so it matches the paths the Trasher checks.
    public static var folder: String { Trasher.resolved(FileManager.default.temporaryDirectory.path) }
}
