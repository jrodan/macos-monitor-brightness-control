import Foundation
import CoreGraphics
import AppKit

public struct Display: Identifiable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public var brightness: Double = 0.5
    public var contrast: Double = 0.5
    public var volume: Double = 0.5
    public let isInternal: Bool
    public var supportsDDC: Bool = false
    public var isSoftwareControl: Bool = false
    
    public init(id: CGDirectDisplayID, name: String, isInternal: Bool) {
        self.id = id
        self.name = name
        self.isInternal = isInternal
    }
}
