import Foundation
import CoreGraphics
import AppKit

struct Display: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Double = 0.5
    var contrast: Double = 0.5
    var volume: Double = 0.5
    let isInternal: Bool
    var supportsDDC: Bool = false
}
