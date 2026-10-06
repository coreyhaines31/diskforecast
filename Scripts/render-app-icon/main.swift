// Renders the app icon set: a drive filling up, with a mark pointing at where it'll be full.
// Usage (from the repo root):
//   swiftc Scripts/render-app-icon/main.swift -o /tmp/render-icon && /tmp/render-icon
import AppKit

let outputDirectory = URL(filePath: "DiskForecast/Assets.xcassets/AppIcon.appiconset")

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)

    // macOS icon grid: the rounded square fills 824/1024 of the canvas.
    let plate = canvas.insetBy(dx: size * 100 / 1024, dy: size * 100 / 1024)
    let plateShape = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.2237, yRadius: plate.height * 0.2237)
    NSGradient(colors: [
        NSColor(red: 0.36, green: 0.62, blue: 0.95, alpha: 1),
        NSColor(red: 0.12, green: 0.27, blue: 0.62, alpha: 1)
    ])!.draw(in: plateShape, angle: -90)

    // The drive: a light body with a dark well that's mostly full.
    let body = NSRect(
        x: plate.minX + plate.width * 0.17, y: plate.minY + plate.height * 0.24,
        width: plate.width * 0.66, height: plate.height * 0.40
    )
    let bodyShape = NSBezierPath(roundedRect: body, xRadius: body.height * 0.18, yRadius: body.height * 0.18)
    NSColor(white: 0.97, alpha: 1).setFill()
    bodyShape.fill()

    // Two screws, so it reads as a drive rather than a battery.
    NSColor(white: 0.70, alpha: 1).setFill()
    for x in [body.minX + body.width * 0.07, body.maxX - body.width * 0.07] {
        let radius = body.height * 0.06
        NSBezierPath(ovalIn: NSRect(x: x - radius, y: body.midY - radius, width: radius * 2, height: radius * 2)).fill()
    }

    let well = body.insetBy(dx: body.width * 0.15, dy: body.height * 0.30)
    let wellShape = NSBezierPath(roundedRect: well, xRadius: well.height * 0.3, yRadius: well.height * 0.3)
    NSColor(red: 0.10, green: 0.18, blue: 0.38, alpha: 1).setFill()
    wellShape.fill()

    let filled = NSRect(x: well.minX, y: well.minY, width: well.width * 0.72, height: well.height)
    NSGraphicsContext.saveGraphicsState()
    wellShape.addClip()
    NSGradient(colors: [
        NSColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1),
        NSColor(red: 1.0, green: 0.50, blue: 0.22, alpha: 1)
    ])!.draw(in: filled, angle: 0)
    NSGraphicsContext.restoreGraphicsState()

    // The forecast: a dashed mark where it'll be full.
    let markX = well.maxX - well.width * 0.10
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: markX, y: body.maxY + plate.height * 0.14))
    mark.line(to: NSPoint(x: markX, y: body.maxY + plate.height * 0.03))
    mark.lineWidth = plate.width * 0.025
    mark.lineCapStyle = .round
    mark.setLineDash([plate.width * 0.04, plate.width * 0.04], count: 2, phase: 0)
    NSColor.white.setStroke()
    mark.stroke()
    let arrow = NSBezierPath()
    let tip = NSPoint(x: markX, y: body.maxY + plate.height * 0.005)
    arrow.move(to: NSPoint(x: tip.x - plate.width * 0.035, y: tip.y + plate.width * 0.04))
    arrow.line(to: tip)
    arrow.line(to: NSPoint(x: tip.x + plate.width * 0.035, y: tip.y + plate.width * 0.04))
    arrow.lineWidth = plate.width * 0.025
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
var images: [[String: String]] = []
for entry in sizes {
    let name = "icon_\(entry.points)x\(entry.points)@\(entry.scale)x.png"
    try! render(entry.points * entry.scale).write(to: outputDirectory.appending(path: name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(entry.scale)x", "size": "\(entry.points)x\(entry.points)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDirectory.appending(path: "Contents.json"))
