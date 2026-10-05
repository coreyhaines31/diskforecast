import AppKit

/// Full Disk Access lets the scan see everything; without it, the scan stays in the parts of
/// the home folder macOS doesn't guard, so it never sets off a stream of permission prompts.
enum FullDiskAccess {
    static var isGranted: Bool {
        // A file only readable with Full Disk Access; opening it never prompts.
        let probe = URL.homeDirectory.appending(path: "Library/Application Support/com.apple.TCC/TCC.db").path
        let descriptor = open(probe, O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Folders that make macOS ask for permission (other apps' data, iCloud Drive, Mail, and so
    /// on). Skipped unless Full Disk Access is on.
    static func protectedFolders(home: String) -> Set<String> {
        let library = [
            "Containers", "Group Containers", "Mobile Documents", "Mail", "Messages", "Safari", "Cookies",
            "HomeKit", "Calendars", "Reminders", "Suggestions", "Biome", "Weather", "Accounts",
            "IdentityServices", "Sharing", "PersonalizationPortrait", "Metadata/CoreSpotlight", "Autosave Information",
            "Application Support/AddressBook", "Application Support/CallHistoryDB",
            "Application Support/com.apple.TCC", "Application Support/Knowledge", "Application Support/FaceTime",
            "Application Support/MobileSync"
        ]
        var folders = Set(library.map { home + "/Library/" + $0 })
        folders.insert(home + "/.Trash")
        folders.insert(home + "/Pictures/Photos Library.photoslibrary")
        return folders
    }
}
