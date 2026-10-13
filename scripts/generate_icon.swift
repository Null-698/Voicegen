// Generates the committed app icon artwork at build time using macOS CoreGraphics.
// The repository stores this source rather than a separate opaque binary asset.
import AppKit
import CoreGraphics
import Foundation

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("Cannot create icon bitmap") }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}
func gradient(_ colors: [CGColor], _ locations: [CGFloat],
              from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray,
                              locations: locations)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [])
}
let bounds = CGRect(x: 0, y: 0, width: size, height: size)
gradient([color(0.015, 0.03, 0.10), color(0.06, 0.14, 0.28),
          color(0.025, 0.02, 0.10)], [0, 0.5, 1],
         from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1024, y: 1024))

let orb = CGRect(x: 108, y: 111, width: 808, height: 808)
context.saveGState()
context.addEllipse(in: orb)
context.clip()
gradient([color(0.04, 0.17, 0.35), color(0.045, 0.08, 0.23),
          color(0.07, 0.03, 0.23)], [0, 0.52, 1],
         from: CGPoint(x: 112, y: 865), to: CGPoint(x: 875, y: 150))
context.restoreGState()

context.saveGState()
context.setShadow(offset: .zero, blur: 32, color: color(0.03, 0.75, 1, 0.9))
context.setLineWidth(9)
context.setStrokeColor(color(0.31, 0.85, 1, 0.94))
context.strokeEllipse(in: orb.insetBy(dx: 5, dy: 5))
context.restoreGState()

let heights: [CGFloat] = [185, 320, 465, 320, 185]
let barWidth: CGFloat = 87
let spacing: CGFloat = 32
let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
let left = (CGFloat(size) - total) / 2
for (index, height) in heights.enumerated() {
    let rectangle = CGRect(x: left + CGFloat(index) * (barWidth + spacing),
                           y: (CGFloat(size) - height) / 2,
                           width: barWidth, height: height)
    let path = CGPath(roundedRect: rectangle,
                      cornerWidth: barWidth / 2, cornerHeight: barWidth / 2,
                      transform: nil)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 22, color: color(0.12, 0.8, 1, 0.7))
    context.addPath(path)
    context.setFillColor(color(0.13, 0.83, 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    gradient([color(0.42, 1, 1), color(0.17, 0.72, 1), color(0.4, 0.42, 1)],
             [0, 0.55, 1],
             from: CGPoint(x: rectangle.midX, y: rectangle.maxY),
             to: CGPoint(x: rectangle.midX, y: rectangle.minY))
    context.restoreGState()
}

guard let image = context.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else { fatalError("Cannot export icon PNG") }

let destination = URL(fileURLWithPath:
    "Sources/Voicegen/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
try data.write(to: destination, options: .atomic)
print("Wrote \\(destination.path)")
