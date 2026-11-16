import DiskForecastCore
import PanelKit
import SwiftUI

/// Each category's LED colour, so the meter shows where the space is going. Neighbours in
/// `StorageBreakdown.meterOrder` alternate light and dark as well as hue, so they stay apart for
/// colour-blind eyes too. Red stays the Trash's, and System and other is a dim grey, the leftover.
extension StorageCategory {
    /// The bright set lights the meter's black recess in both appearances and the dark card's
    /// metal; the deeper set reads on light metal.
    func ledColor(onDark: Bool) -> Color {
        if self == .trash { return onDark ? PanelTheme.dark.stop : PanelTheme.light.stop }
        let (bright, deep) = ledHex
        return Color(ledHex: onDark ? bright : deep)
    }

    private var ledHex: (bright: UInt32, deep: UInt32) {
        switch self {
        case .apps: (0x4E9BFF, 0x2F74E0)
        case .developer: (0xF2A03A, 0xD98A1A)
        case .photos: (0xE8428F, 0xD02E7C)
        case .movies: (0x8A5CFF, 0x7445E8)
        case .documents: (0x62DCE8, 0x1BA9BA)
        case .music: (0x2F9E4C, 0x23883E)
        case .caches: (0xF5E04A, 0xC9A800)
        case .other: (0x6E7378, 0x7E8286)
        case .trash: (0, 0)
        }
    }
}

private extension Color {
    init(ledHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
