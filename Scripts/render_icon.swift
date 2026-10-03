import AppKit
import Foundation

// A vector-drawn sunrise: no external image assets or dependencies.
let output = CommandLine.arguments.dropFirst().first ?? "MorningReset/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let graphics = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let context = NSGraphicsContext(cgContext: graphics, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let orange = NSColor(red: 0.73, green: 0.35, blue: 0.17, alpha: 1)
orange.setFill()
let sun = NSBezierPath()
sun.move(to: NSPoint(x: 280, y: 452))
sun.appendArc(withCenter: NSPoint(x: 512, y: 452), radius: 232, startAngle: 180, endAngle: 0, clockwise: true)
sun.close()
sun.fill()
orange.setStroke()
func stroke(_ from: NSPoint, _ to: NSPoint, width: CGFloat) {
    let path = NSBezierPath(); path.lineWidth = width; path.lineCapStyle = .round
    path.move(to: from); path.line(to: to); path.stroke()
}
stroke(NSPoint(x: 220, y: 410), NSPoint(x: 804, y: 410), width: 44)
for angle in [30.0, 60.0, 90.0, 120.0, 150.0] {
    let radians = angle * .pi / 180
    stroke(NSPoint(x: 512 + cos(radians) * 307, y: 452 + sin(radians) * 307),
           NSPoint(x: 512 + cos(radians) * 363, y: 452 + sin(radians) * 363), width: 34)
}
NSColor(red: 0.29, green: 0.26, blue: 0.23, alpha: 1).setStroke()
stroke(NSPoint(x: 340, y: 308), NSPoint(x: 684, y: 308), width: 32)
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: graphics.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
