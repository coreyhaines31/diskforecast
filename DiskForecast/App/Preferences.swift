import Foundation

enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case freeSpace
    case percentFree
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeSpace: "Free space"
        case .percentFree: "Percent free"
        case .iconOnly: "Icon only"
        }
    }
}

enum Preferences {
    static let menuBarDisplayKey = "menuBarDisplay"
    static let staleAfterDaysKey = "staleAfterDays"
    static let onboardingDoneKey = "onboardingDone"
    static let appliedLaunchAtLoginDefaultKey = "appliedLaunchAtLoginDefault"
    static let notifiesBeforeFullKey = "notifiesBeforeFull"
    static let lastDiskAlertKey = "lastDiskAlert"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            menuBarDisplayKey: MenuBarDisplay.freeSpace.rawValue,
            staleAfterDaysKey: 30,
            onboardingDoneKey: false,
            notifiesBeforeFullKey: true
        ])
    }

    static var menuBarDisplay: MenuBarDisplay {
        MenuBarDisplay(rawValue: UserDefaults.standard.string(forKey: menuBarDisplayKey) ?? "") ?? .freeSpace
    }

    static var staleAfterDays: Int {
        max(1, UserDefaults.standard.integer(forKey: staleAfterDaysKey))
    }

    static var onboardingDone: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingDoneKey) }
    }

    static var appliedLaunchAtLoginDefault: Bool {
        get { UserDefaults.standard.bool(forKey: appliedLaunchAtLoginDefaultKey) }
        set { UserDefaults.standard.set(newValue, forKey: appliedLaunchAtLoginDefaultKey) }
    }

    static var notifiesBeforeFull: Bool {
        UserDefaults.standard.bool(forKey: notifiesBeforeFullKey)
    }

    static var lastDiskAlert: Date? {
        get { UserDefaults.standard.object(forKey: lastDiskAlertKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastDiskAlertKey) }
    }
}
