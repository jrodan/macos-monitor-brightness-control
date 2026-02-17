import Foundation
import CoreGraphics

public class SoftwareDimmingManager {
    public static func setBrightness(for displayID: CGDirectDisplayID, to value: Double) {
        applyGamma(for: displayID, brightness: value, contrast: 1.0)
    }

    public static func setContrast(for displayID: CGDirectDisplayID, to value: Double) {
        // We can't actually change the hardware contrast on HDMI, but we can't really sync contrast well via software either.
        // However, we can store the value or apply a non-linear gamma curve if needed.
        // For now, we'll keep it simple: software contrast is hard to do without losing color information.
    }

    private static func applyGamma(for displayID: CGDirectDisplayID, brightness: Double, contrast: Double) {
        let sampleCount = 256
        var redTable = [CGGammaValue](repeating: 0, count: sampleCount)
        var greenTable = [CGGammaValue](repeating: 0, count: sampleCount)
        var blueTable = [CGGammaValue](repeating: 0, count: sampleCount)
        
        // Brightness factor (0.0 to 1.0)
        let b = Float(max(min(brightness, 1.0), 0.0))
        
        for i in 0..<sampleCount {
            let colorVal = Float(i) / Float(sampleCount - 1) * b
            redTable[i] = CGGammaValue(colorVal)
            greenTable[i] = CGGammaValue(colorVal)
            blueTable[i] = CGGammaValue(colorVal)
        }
        
        CGSetDisplayTransferByTable(displayID, UInt32(sampleCount), &redTable, &greenTable, &blueTable)
    }
}
