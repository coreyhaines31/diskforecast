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

/// How the menu card draws the storage meter.
enum StorageMeterStyle: String, CaseIterable, Identifiable {
    case peak
    case vuMeter = "vu"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .peak: "Peak meter"
        case .vuMeter: "VU meter"
        }
    }
}

enum Preferences {
    static let menuBarDisplayKey = "menuBarDisplay"
    static let storageMeterStyleKey = "storageMeterStyle"
    static let staleAfterDaysKey = "staleAfterDays"
    static let onboardingDoneKey = "onboardingDone"
    static let appliedLaunchAtLoginDefaultKey = "appliedLaunchAtLoginDefault"
    static let notifiesBeforeFullKey = "notifiesBeforeFull"
    static let lastDiskAlertKey = "lastDiskAlert"
    static let lastFastFillAlertKey = "lastFastFillAlert"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            menuBarDisplayKey: MenuBarDisplay.freeSpace.rawValue,
            storageMeterStyleKey: StorageMeterStyle.peak.rawValue,
            staleAfterDaysKey: 30,
            onboardingDoneKey: false,
            notifiesBeforeFullKey: true
        ])
    }

    static var menuBarDisplay: MenuBarDisplay {
        MenuBarDisplay(rawValue: UserDefaults.standard.string(forKey: menuBarDisplayKey) ?? "") ?? .freeSpace
    }

    static var storageMeterStyle: StorageMeterStyle {
        StorageMeterStyle(rawValue: UserDefaults.standard.string(forKey: storageMeterStyleKey) ?? "") ?? .peak
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

    static var lastFastFillAlert: Date? {
        get { UserDefaults.standard.object(forKey: lastFastFillAlertKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastFastFillAlertKey) }
    }
}
