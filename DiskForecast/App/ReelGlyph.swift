import AppKit

/// The menu bar glyph: a tape reel seen through its three windows. The fuller the disk, the more
/// tape fills the windows; nearly full leaves only a sliver of each. Same geometry as the family's
/// glyph source (mac-app-kit `Scripts/glyphs/glyphs.mjs`, `disk`), drawn here because the
/// generated PDFs keep their knockouts in a mask that AppKit doesn't draw.
enum ReelGlyph {
    enum State: String {
        case roomy, filling, nearlyFull

        /// How much tape is wound on, 0...1, as in glyphs.mjs.
        var tape: CGFloat {
            switch self {
            case .roomy: 0.1
            case .filling: 0.55
            case .nearlyFull: 0.83
            }
        }
    }

    static func state(percentUsed: Double, isLow: Bool) -> State {
        if isLow || percentUsed >= 0.8 { return .nearlyFull }
        return percentUsed >= 0.4 ? .filling : .roomy
    }

    /// An 18 pt template image.
    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.black.cgColor)
            context.fillEllipse(in: circle(9, 9, 8.1))
            context.setBlendMode(.clear)
            for degrees in [0.0, 120, 240] {
                let angle = (degrees - 90) * .pi / 180
                context.fillEllipse(in: circle(9 + 4.3 * cos(angle), 9 + 4.3 * sin(angle), 2.15))
            }
            context.setBlendMode(.normal)
            context.fillEllipse(in: circle(9, 9, 2.3 + state.tape * 4.3))
            context.setBlendMode(.clear)
            context.fillEllipse(in: circle(9, 9, 1))
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> CGRect {
        CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
    }
}
