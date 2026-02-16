import Foundation
import AppKit

let size = 1024
let imgSize = NSSize(width: size, height: size)
let image = NSImage(size: imgSize)

image.lockFocus()

let context = NSGraphicsContext.current!.cgContext

// 1. Background: The "Squircle" (Standard macOS App Icon Shape)
let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: 180, yRadius: 180)

// Gradient for the background (Deep Blue to Slate)
let bgGradient = NSGradient(starting: NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.2, alpha: 1.0),
                            ending: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.1, alpha: 1.0))!
bgGradient.draw(in: squirclePath, angle: -90)

// 2. The Sun (Yellow Glow)
let sunCenter = CGPoint(x: size / 2, y: size / 2)
let sunRadius = 220.0
let sunRect = CGRect(x: sunCenter.x - CGFloat(sunRadius), y: sunCenter.y - CGFloat(sunRadius), width: CGFloat(sunRadius * 2), height: CGFloat(sunRadius * 2))

let sunGradient = NSGradient(starting: NSColor.yellow, ending: NSColor.orange)!
let sunPath = NSBezierPath(ovalIn: sunRect)
sunGradient.draw(in: sunPath, relativeCenterPosition: .zero)

// 3. Rays (Brightness Symbol)
let rayCount = 12
let rayLength = 320.0
let rayInner = 260.0
let rayWidth = 25.0

NSColor.white.withAlphaComponent(0.8).setStroke()
for i in 0..<rayCount {
    let angle = CGFloat(i) * (.pi * 2) / CGFloat(rayCount)
    let start = CGPoint(x: sunCenter.x + cos(angle) * CGFloat(rayInner), y: sunCenter.y + sin(angle) * CGFloat(rayInner))
    let end = CGPoint(x: sunCenter.x + cos(angle) * CGFloat(rayLength), y: sunCenter.y + sin(angle) * CGFloat(rayLength))
    
    let rayPath = NSBezierPath()
    rayPath.lineWidth = CGFloat(rayWidth)
    rayPath.lineCapStyle = .round
    rayPath.move(to: start)
    rayPath.line(to: end)
    rayPath.stroke()
}

image.unlockFocus()

// Save to the AppIcon set
let url = URL(fileURLWithPath: "/Users/jrodan/dev/jan/brightness-control-macos/Sources/BrightnessControl/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
    let png = bitmap.representation(using: .png, properties: [:])
    try? png?.write(to: url)
}
