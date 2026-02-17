import Foundation
import Carbon

@MainActor
public class HotKeyManager {
    public static let shared = HotKeyManager()
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    public var onHotKey: ((UInt32) -> Void)?

    public func register(id: UInt32, keyCode: Int, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x42524947), id: id) // "BRIG"
        
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[id] = ref
        }
    }

    public func setupHandler() {
        let eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr, let userData = userData {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.onHotKey?(hotKeyID.id)
                }
            }
            
            return noErr
        }, 1, [eventType], pointer, &handlerRef)
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
        }
    }
}
