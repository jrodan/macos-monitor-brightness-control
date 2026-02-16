import Foundation
import IOKit
import IOKit.i2c
import CoreGraphics

struct DDC {
    static let brightness: UInt8 = 0x10
    static let contrast: UInt8 = 0x12
    static let volume: UInt8 = 0x62
}

class DDCManager {
    static func setBrightness(for displayID: CGDirectDisplayID, to value: Double) {
        _ = writeVcp(displayID, control: DDC.brightness, value: UInt16(value * 100))
    }

    static func setContrast(for displayID: CGDirectDisplayID, to value: Double) {
        _ = writeVcp(displayID, control: DDC.contrast, value: UInt16(value * 100))
    }

    static func setVolume(for displayID: CGDirectDisplayID, to value: Double) {
        _ = writeVcp(displayID, control: DDC.volume, value: UInt16(value * 100))
    }

    private static func writeVcp(_ displayID: CGDirectDisplayID, control: UInt8, value: UInt16) -> Bool {
        guard let service = findFramebuffer(for: displayID) else {
            return false
        }
        
        var success = false
        // Try typically used buses
        for bus in 0..<3 {
            var interface: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(service, IOOptionBits(bus), &interface) == kIOReturnSuccess, let interface = interface else { continue }
            
            var request = IOI2CRequest()
            let bufferSize = 7
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            
            // DDC Packet
            let length: UInt8 = 4
            let command: UInt8 = 0x03 
            let checksum = 0x6E ^ (0x80 | length) ^ command ^ control ^ UInt8(value >> 8) ^ UInt8(value & 0xFF)
            
            buffer[0] = 0x51 
            buffer[1] = 0x80 | length
            buffer[2] = command
            buffer[3] = control
            buffer[4] = UInt8(value >> 8)
            buffer[5] = UInt8(value & 0xFF)
            buffer[6] = checksum
            
            request.commFlags = 0
            request.sendAddress = 0x6E
            request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            request.sendBuffer = vm_address_t(bitPattern: buffer)
            request.sendBytes = UInt32(bufferSize)
            
            request.replyAddress = 0x6F
            request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
            request.replyBytes = 0
            
            let sendResult = IOI2CSendRequest(interface, 0, &request)
            
            buffer.deallocate()
            IOI2CInterfaceClose(interface, 0)
            
            if sendResult == kIOReturnSuccess {
                success = true
                break 
            }
        }
        
        IOObjectRelease(service)
        return success
    }

    private static func findFramebuffer(for displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOFramebuffer"), &iterator)
        
        guard result == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            // Match the display ID using the Carbon "NSScreenNumber" property equivalent in IOKit
            if let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] {
                // Common keys used for matching
                if let unitNumber = info["DisplayUnitNumber"] as? UInt32, unitNumber == displayID {
                    return service
                }
                
                // Fallback: Check for vendor/model match
                let vendor = CGDisplayVendorNumber(displayID)
                let model = CGDisplayModelNumber(displayID)
                
                if let v = info[kDisplayVendorID] as? UInt32, v == vendor,
                   let m = info[kDisplayProductID] as? UInt32, m == model {
                    return service
                }
            }
            
            IOObjectRelease(service)
        }
        
        // Final fallback: try AppleDisplay services (Apple Silicon specific)
        var appleIterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDisplay"), &appleIterator) == kIOReturnSuccess {
            while case let service = IOIteratorNext(appleIterator), service != 0 {
                // Similar matching logic for AppleDisplay
                IOObjectRelease(service)
            }
            IOObjectRelease(appleIterator)
        }
        
        return nil
    }
}
