import Foundation
import IOKit
import IOKit.ps
import SwiftUI

@MainActor
public class BatteryManager: ObservableObject {
    @Published public var percentage: Int = 0
    @Published public var isCharging: Bool = false
    @Published public var isOnAC: Bool = false
    @Published public var isLowPowerMode: Bool = false
    @Published public var showBattery: Bool = false {
        didSet {
            UserDefaults.standard.set(showBattery, forKey: persistenceKey)
        }
    }
    
    private let persistenceKey = "ShowBatteryInMenuBar"
    private var runLoopSource: CFRunLoopSource?

    public init() {
        self.showBattery = UserDefaults.standard.bool(forKey: persistenceKey)
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        updatePowerStatus()
        setupNotification()
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    public func updatePowerStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { 
            self.isOnAC = true // Assume desktop if no power source info
            return 
        }
        guard let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { 
            self.isOnAC = true
            return 
        }
        
        for item in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, item)?.takeUnretainedValue() as? [String: Any] else { continue }
            
            if let cap = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int {
                self.percentage = Int(Double(cap) / Double(max) * 100)
            }
            
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                self.isOnAC = (state == kIOPSACPowerValue)
            }
            
            if let charging = desc[kIOPSIsChargingKey] as? Bool {
                self.isCharging = charging
            }
        }
    }

    private func setupNotification() {
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
            guard let context = context else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
            
            Task { @MainActor in
                manager.updatePowerStatus()
            }
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, opaqueSelf)?.takeRetainedValue() {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
    
    public var batteryIconName: String {
        if isCharging {
            return "battery.100.bolt"
        }
        
        if percentage >= 100 { return "battery.100" }
        if percentage >= 75 { return "battery.75" }
        if percentage >= 50 { return "battery.50" }
        if percentage >= 25 { return "battery.25" }
        return "battery.0"
    }

    /// Explicit RGB colors for special states; returns .primary for standard native look
    public var batteryColor: Color {
        if isLowPowerMode { return Color(red: 1.0, green: 0.8, blue: 0.0) } // Vibrant Yellow
        if isOnAC { return Color(red: 0.0, green: 0.85, blue: 0.1) } // Vibrant Green
        if percentage <= 10 { return Color(red: 1.0, green: 0.2, blue: 0.2) } // Vibrant Red
        return .primary // Standard system look (White/Black)
    }

    public var isSpecialState: Bool {
        return isLowPowerMode || isOnAC || percentage <= 10
    }

    public var batteryTextColor: Color {
        if isLowPowerMode { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        if isOnAC { return Color(red: 0.0, green: 0.85, blue: 0.1) }
        if percentage <= 10 { return Color(red: 1.0, green: 0.2, blue: 0.2) }
        return .primary
    }
}

