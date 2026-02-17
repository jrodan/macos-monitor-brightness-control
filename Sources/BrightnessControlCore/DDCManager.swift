import Foundation
import IOKit
import IOKit.i2c
import CoreGraphics

struct DDC {
    static let brightness: UInt8 = 0x10
    static let contrast: UInt8 = 0x12
    static let volume: UInt8 = 0x62
}

public struct VcpResult: Sendable {
    public let current: UInt16
    public let max: UInt16
}

public class DDCManager {
    nonisolated(unsafe) private static var busCache: [CGDirectDisplayID: IOOptionBits] = [:]
    nonisolated(unsafe) private static var maxCache: [CGDirectDisplayID: [UInt8: UInt16]] = [:]
    private static let lock = NSLock()

    @discardableResult
    public static func setBrightness(for displayID: CGDirectDisplayID, to value: Double) -> Bool {
        let maxVal = getMax(for: displayID, control: DDC.brightness)
        let v = UInt16(min(Double(maxVal), value * Double(maxVal)))
        return writeVcp(displayID, control: DDC.brightness, value: v)
    }

    @discardableResult
    public static func setContrast(for displayID: CGDirectDisplayID, to value: Double) -> Bool {
        let maxVal = getMax(for: displayID, control: DDC.contrast)
        let v = UInt16(min(Double(maxVal), value * Double(maxVal)))
        return writeVcp(displayID, control: DDC.contrast, value: v)
    }

    @discardableResult
    public static func setVolume(for displayID: CGDirectDisplayID, to value: Double) -> Bool {
        let maxVal = getMax(for: displayID, control: DDC.volume)
        let v = UInt16(min(Double(maxVal), value * Double(maxVal)))
        return writeVcp(displayID, control: DDC.volume, value: v)
    }

    private static func getMax(for displayID: CGDirectDisplayID, control: UInt8) -> UInt16 {
        lock.lock()
        let cached = maxCache[displayID]?[control]
        lock.unlock()
        if let val = cached { return val }
        
        if let result = readVcpEx(displayID, control: control) {
            lock.lock()
            if maxCache[displayID] == nil { maxCache[displayID] = [:] }
            maxCache[displayID]?[control] = result.max
            lock.unlock()
            return result.max
        }
        return 100
    }

    public static func getBrightness(for displayID: CGDirectDisplayID) -> Double? {
        guard let result = readVcpEx(displayID, control: DDC.brightness) else { return nil }
        return Double(result.current) / Double(max(1, result.max))
    }

    public static func getContrast(for displayID: CGDirectDisplayID) -> Double? {
        guard let result = readVcpEx(displayID, control: DDC.contrast) else { return nil }
        return Double(result.current) / Double(max(1, result.max))
    }

    public static func getVolume(for displayID: CGDirectDisplayID) -> Double? {
        guard let result = readVcpEx(displayID, control: DDC.volume) else { return nil }
        return Double(result.current) / Double(max(1, result.max))
    }

    public static func writeVcp(_ displayID: CGDirectDisplayID, control: UInt8, value: UInt16) -> Bool {
        guard let service = findFramebuffer(for: displayID) else { return false }
        defer { IOObjectRelease(service) }
        
        lock.lock()
        defer { lock.unlock() }

        let cachedBus = busCache[displayID]
        
        if let bus = cachedBus {
            if performWrite(service: service, bus: bus, control: control, value: value) {
                return true
            }
            busCache.removeValue(forKey: displayID)
        }
        
        for bus in 0..<15 {
            if performWrite(service: service, bus: IOOptionBits(bus), control: control, value: value) {
                busCache[displayID] = IOOptionBits(bus)
                return true
            }
        }
        return false
    }

    private static func performWrite(service: io_service_t, bus: IOOptionBits, control: UInt8, value: UInt16) -> Bool {
        var interface: IOI2CConnectRef?
        let ret = IOI2CInterfaceOpen(service, bus, &interface)
        guard ret == kIOReturnSuccess, let interface = interface else { return false }
        defer { IOI2CInterfaceClose(interface, 0) }
        
        var request = IOI2CRequest()
        let bufferSize = 7
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        buffer[0] = 0x51                
        buffer[1] = 0x84        
        buffer[2] = 0x03                
        buffer[3] = control              
        buffer[4] = UInt8(value >> 8)    
        buffer[5] = UInt8(value & 0xFF)  
        
        var checksum: UInt8 = 0x6E
        for i in 0..<6 { checksum ^= buffer[i] }
        buffer[6] = checksum
        
        request.commFlags = 0
        request.sendAddress = 0x6E
        request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.sendBuffer = vm_address_t(bitPattern: buffer)
        request.sendBytes = UInt32(bufferSize)
        request.replyAddress = 0x6F
        request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
        request.replyBytes = 0
        
        return IOI2CSendRequest(interface, 0, &request) == kIOReturnSuccess
    }

    public static func readVcpEx(_ displayID: CGDirectDisplayID, control: UInt8) -> VcpResult? {
        guard let service = findFramebuffer(for: displayID) else { return nil }
        defer { IOObjectRelease(service) }
        
        lock.lock()
        defer { lock.unlock() }

        let cachedBus = busCache[displayID]
        
        if let bus = cachedBus {
            if let result = performRead(service: service, bus: bus, control: control) {
                return result
            }
            busCache.removeValue(forKey: displayID)
        }
        
        for bus in 0..<15 {
            if let result = performRead(service: service, bus: IOOptionBits(bus), control: control) {
                busCache[displayID] = IOOptionBits(bus)
                return result
            }
        }
        return nil
    }

    private static func performRead(service: io_service_t, bus: IOOptionBits, control: UInt8) -> VcpResult? {
        var interface: IOI2CConnectRef?
        let ret = IOI2CInterfaceOpen(service, bus, &interface)
        guard ret == kIOReturnSuccess, let interface = interface else { return nil }
        defer { IOI2CInterfaceClose(interface, 0) }
        
        var request = IOI2CRequest()
        let sendBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 5)
        defer { sendBuffer.deallocate() }
        
        sendBuffer[0] = 0x51                
        sendBuffer[1] = 0x82                
        sendBuffer[2] = 0x01                
        sendBuffer[3] = control             
        
        var checksum: UInt8 = 0x6E
        for i in 0..<4 { checksum ^= sendBuffer[i] }
        sendBuffer[4] = checksum
        
        request.commFlags = 0
        request.sendAddress = 0x6E
        request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.sendBuffer = vm_address_t(bitPattern: sendBuffer)
        request.sendBytes = 5
        
        request.replyAddress = 0x6F
        request.replyTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        let replyBufferSize = 11
        let replyBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: replyBufferSize)
        defer { replyBuffer.deallocate() }
        
        replyBuffer.initialize(repeating: 0, count: replyBufferSize)
        request.replyBuffer = vm_address_t(bitPattern: replyBuffer)
        request.replyBytes = UInt32(replyBufferSize)
        request.minReplyDelay = 50 
        
        if IOI2CSendRequest(interface, 0, &request) == kIOReturnSuccess {
            for i in 0..<4 {
                if replyBuffer[i] == 0x02 && replyBuffer[i+2] == control {
                    let maxH = replyBuffer[i+4]
                    let maxL = replyBuffer[i+5]
                    let curH = replyBuffer[i+6]
                    let curL = replyBuffer[i+7]
                    return VcpResult(current: (UInt16(curH) << 8) | UInt16(curL),
                                   max: (UInt16(maxH) << 8) | UInt16(maxL))
                }
            }
        }
        return nil
    }
    
    public static func readVcp(_ displayID: CGDirectDisplayID, control: UInt8) -> UInt16? {
        return readVcpEx(displayID, control: control)?.current
    }

    private static func findFramebuffer(for displayID: CGDirectDisplayID) -> io_service_t? {
        let vendor = CGDisplayVendorNumber(displayID)
        let model = CGDisplayModelNumber(displayID)
        let matchingClasses = ["IOFramebuffer", "IOMobileFramebuffer", "AppleDisplay"]
        for className in matchingClasses {
            var iterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == kIOReturnSuccess {
                while case let service = IOIteratorNext(iterator), service != 0 {
                    if let props = getProperties(service), match(props, vendor: vendor, model: model) {
                        IOObjectRelease(iterator)
                        return service
                    }
                    var currentParent = service
                    while true {
                        var parent: io_registry_entry_t = 0
                        if IORegistryEntryGetParentEntry(currentParent, kIOServicePlane, &parent) == kIOReturnSuccess {
                            if let pprops = getProperties(parent), match(pprops, vendor: vendor, model: model) {
                                if currentParent != service { IOObjectRelease(currentParent) }
                                IOObjectRelease(parent)
                                IOObjectRelease(iterator)
                                return service 
                            }
                            if currentParent != service { IOObjectRelease(currentParent) }
                            currentParent = parent
                        } else {
                            if currentParent != service { IOObjectRelease(currentParent) }
                            break
                        }
                    }
                    IOObjectRelease(service)
                }
                IOObjectRelease(iterator)
            }
        }
        return nil
    }

    private static func match(_ props: [String: Any], vendor: UInt32, model: UInt32) -> Bool {
        if let v = (props[kDisplayVendorID] as? NSNumber)?.uint32Value, v == vendor,
           let m = (props[kDisplayProductID] as? NSNumber)?.uint32Value, m == model {
            return true
        }
        if let attr = props["DisplayAttributes"] as? [String: Any],
           let prod = attr["ProductAttributes"] as? [String: Any] {
            let v = (prod["LegacyManufacturerID"] as? NSNumber)?.uint32Value ?? (prod["ManufacturerID"] as? NSNumber)?.uint32Value
            let m = (prod["ProductID"] as? NSNumber)?.uint32Value ?? (prod["ModelID"] as? NSNumber)?.uint32Value
            if v == vendor && m == model { return true }
        }
        return false
    }

    private static func getProperties(_ service: io_service_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess, let p = props {
            return p.takeRetainedValue() as? [String: Any]
        }
        return nil
    }
}
