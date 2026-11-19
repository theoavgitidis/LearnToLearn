import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = destination.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func image(size: Int) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(srgbRed: 0.09, green: 0.12, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 213, yRadius: 213).fill()
    let gradient = NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.26, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.10, green: 0.14, blue: 0.12, alpha: 1))!
    gradient.draw(in: NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 207, yRadius: 207), angle: -60)
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: -0.19)
    NSColor(srgbRed: 0.47, green: 0.60, blue: 0.44, alpha: 0.38).setFill()
    NSBezierPath(roundedRect: NSRect(x: -230, y: -266, width: 432, height: 528), xRadius: 65, yRadius: 65).fill()
    context.restoreGState()
    context.saveGState()
    context.translateBy(x: 536, y: 528)
    context.rotate(by: 0.13)
    NSColor(srgbRed: 0.93, green: 0.67, blue: 0.45, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: -210, y: -264, width: 420, height: 528), xRadius: 62, yRadius: 62).fill()
    NSColor(srgbRed: 0.16, green: 0.21, blue: 0.16, alpha: 1).setFill()
    let star = NSBezierPath()
    star.move(to: NSPoint(x: 0, y: 166)); star.curve(to: NSPoint(x: 100, y: 60), controlPoint1: NSPoint(x: 15, y: 89), controlPoint2: NSPoint(x: 28, y: 77))
    star.curve(to: NSPoint(x: 0, y: -46), controlPoint1: NSPoint(x: 28, y: 44), controlPoint2: NSPoint(x: 15, y: 27))
    star.curve(to: NSPoint(x: -100, y: 60), controlPoint1: NSPoint(x: -15, y: 27), controlPoint2: NSPoint(x: -28, y: 44))
    star.curve(to: NSPoint(x: 0, y: 166), controlPoint1: NSPoint(x: -28, y: 77), controlPoint2: NSPoint(x: -15, y: 89)); star.fill()
    NSColor(srgbRed: 0.16, green: 0.21, blue: 0.16, alpha: 0.55).setFill()
    NSBezierPath(roundedRect: NSRect(x: -95, y: -127, width: 190, height: 16), xRadius: 8, yRadius: 8).fill()
    NSBezierPath(roundedRect: NSRect(x: -60, y: -171, width: 120, height: 16), xRadius: 8, yRadius: 8).fill()
    context.restoreGState()
    image.unlockFocus()
    let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return representation.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try image(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try image(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", destination.appendingPathComponent("AppIcon.icns").path]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil fehlgeschlagen") }
try FileManager.default.removeItem(at: iconset)
