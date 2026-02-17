import Foundation
import CoreGraphics
import AppKit
import ServiceManagement

@MainActor
public class BrightnessManager: ObservableObject {
    @Published public var displays: [Display] = []
    @Published public var autostartEnabled: Bool = false
    @Published public var showInDock: Bool = false {
        didSet {
            updateActivationPolicy()
        }
    }
    @Published public var syncAllDisplays: Bool = false
    @Published public var showSceneGallery: Bool = true {
        didSet {
            UserDefaults.standard.set(showSceneGallery, forKey: "ShowSceneGallery")
        }
    }
    
    private let persistenceKey = "SavedBrightnessLevels"
    private let contrastKey = "SavedContrastLevels"
    private let volumeKey = "SavedVolumeLevels"
    private let dockPersistenceKey = "ShowInDock"
    private let syncKey = "SyncAllDisplays"
    
    public init() {
        self.showInDock = UserDefaults.standard.bool(forKey: dockPersistenceKey)
        self.syncAllDisplays = UserDefaults.standard.bool(forKey: syncKey)
        
        let galleryPref = UserDefaults.standard.object(forKey: "ShowSceneGallery")
        if let val = galleryPref as? Bool {
            self.showSceneGallery = val
        } else {
            self.showSceneGallery = true // Default to true
        }
        
        refreshDisplays()
        
        checkAutostartStatus()
        setupDisplayCallback()
        setupBrightnessObserver()
        updateActivationPolicy()
        setupHotKeys()
    }
    
    private func setupBrightnessObserver() {
        // Poll for changes to internal brightness from OS keys/System Settings
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncWithPhysicalBrightness()
            }
        }
    }
    
    private func syncWithPhysicalBrightness() {
        for i in 0..<displays.count {
            if displays[i].isInternal {
                let current = getInternalBrightness(for: displays[i].id)
                if abs(Double(current) - displays[i].brightness) > 0.01 {
                    displays[i].brightness = Double(current)
                    
                    if syncAllDisplays {
                        // If sync is on, propogate the OS-driven change to others
                        setBrightness(for: displays[i], to: Double(current))
                    }
                }
            }
        }
    }
    
    private func setupHotKeys() {
        HotKeyManager.shared.onHotKey = { [weak self] id in
            Task { @MainActor in
                if id == 1 { // Up
                    self?.adjustAllBrightness(by: 0.1)
                } else if id == 2 { // Down
                    self?.adjustAllBrightness(by: -0.1)
                }
            }
        }
        
        // Modifiers: Control+Option (6144)
        HotKeyManager.shared.register(id: 1, keyCode: 126, modifiers: 6144) // Arrow Up
        HotKeyManager.shared.register(id: 2, keyCode: 125, modifiers: 6144) // Arrow Down
        HotKeyManager.shared.setupHandler()
    }
    
    private func adjustAllBrightness(by delta: Double) {
        var firstValue: Double?
        for display in displays {
            let newValue = min(max(display.brightness + delta, 0), 1)
            setBrightness(for: display, to: newValue)
            if firstValue == nil { firstValue = newValue }
        }
        if let val = firstValue {
            OSDManager.shared.show(brightness: val)
        }
    }
    
    private func setupDisplayCallback() {
        let callback: CGDisplayReconfigurationCallBack = { (display, flags, userInfo) in
            guard flags.contains(.beginConfigurationFlag) == false else { return }
            Task { @MainActor in
                if let userInfo = userInfo {
                    let manager = Unmanaged<BrightnessManager>.fromOpaque(userInfo).takeUnretainedValue()
                    manager.refreshDisplays()
                }
            }
        }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(callback, pointer)
    }
    
    private func updateActivationPolicy() {
        // Only attempt to set activation policy if we are running in a regular app context
        if NSApp != nil {
            if showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        UserDefaults.standard.set(showInDock, forKey: dockPersistenceKey)
    }
    
    public func refreshDisplays() {
        var newDisplays: [Display] = []
        let savedBrightness = UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: Double] ?? [:]
        let savedContrast = UserDefaults.standard.dictionary(forKey: contrastKey) as? [String: Double] ?? [:]
        let savedVolume = UserDefaults.standard.dictionary(forKey: volumeKey) as? [String: Double] ?? [:]

        let screens = NSScreen.screens
        for screen in screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            
            let name = screen.localizedName
            let isInternal = CGDisplayIsBuiltin(displayID) != 0
            
            var display = Display(id: displayID, name: name, isInternal: isInternal)
            display.brightness = savedBrightness[name] ?? 0.5
            display.contrast = savedContrast[name] ?? 0.5
            display.volume = savedVolume[name] ?? 0.5
            display.supportsDDC = !isInternal
            
            // Try to sync with hardware actual state if external and not previously saved
            if !isInternal {
                if let hardwareBrightness = DDCManager.getBrightness(for: displayID) {
                    display.brightness = hardwareBrightness
                    display.isSoftwareControl = false
                } else {
                    display.isSoftwareControl = true
                }
                
                if let hardwareContrast = DDCManager.getContrast(for: displayID) {
                    display.contrast = hardwareContrast
                }
                
                if let hardwareVolume = DDCManager.getVolume(for: displayID) {
                    display.volume = hardwareVolume
                }
            }
            
            newDisplays.append(display)
            
            // Apply initial brightness (to ensure app state and hardware are aligned)
            if isInternal {
                setInternalBrightness(for: displayID, to: Float(display.brightness))
            } else {
                if !DDCManager.setBrightness(for: displayID, to: display.brightness) {
                    SoftwareDimmingManager.setBrightness(for: displayID, to: display.brightness)
                    display.isSoftwareControl = true
                }
            }
        }
        self.displays = newDisplays
    }

    public func setBrightness(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].brightness = value
        }
        
        if display.isInternal {
            setInternalBrightness(for: display.id, to: Float(value))
        } else {
            // "True Black" Hybrid Mode logic
            // We use DDC for the 0.1 to 1.0 range.
            // When below 0.1, we keep DDC at 0 and use software dimming for the rest.
            
            let hardwareValue: Double
            let softwareValue: Double
            
            if value >= 0.1 {
                hardwareValue = (value - 0.1) / 0.9
                softwareValue = 1.0
            } else {
                hardwareValue = 0.0
                softwareValue = value / 0.1
            }

            let success = DDCManager.setBrightness(for: display.id, to: hardwareValue)
            
            if let index = displays.firstIndex(where: { $0.id == display.id }) {
                displays[index].isSoftwareControl = !success || value < 0.1
            }

            if !success {
                SoftwareDimmingManager.setBrightness(for: display.id, to: value)
            } else {
                SoftwareDimmingManager.setBrightness(for: display.id, to: softwareValue)
            }
        }
        
        if syncAllDisplays {
            for i in displays.indices {
                if displays[i].id != display.id {
                    setBrightness(for: displays[i], to: value)
                }
            }
        }
        
        var saved = UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: persistenceKey)
    }

    public func setContrast(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].contrast = value
        }
        if !display.isInternal {
            _ = DDCManager.setContrast(for: display.id, to: value)
            // Software contrast is currently not supported for HDMI displays
            // due to potential color information loss.
        }
        var saved = UserDefaults.standard.dictionary(forKey: contrastKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: contrastKey)
    }

    public func setVolume(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].volume = value
        }
        if !display.isInternal {
            _ = DDCManager.setVolume(for: display.id, to: value)
            // Volume is strictly a hardware control; if DDC is blocked,
            // we cannot change the monitor's internal volume.
        }
        var saved = UserDefaults.standard.dictionary(forKey: volumeKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: volumeKey)
    }

    public enum Preset: String, CaseIterable, Sendable {
        case cinema, reading, night, outdoor, focus
        
        public var brightness: Double {
            switch self {
            case .cinema: return 0.8
            case .reading: return 0.4
            case .night: return 0.1
            case .outdoor: return 1.0
            case .focus: return 0.6
            }
        }
        
        public var icon: String {
            switch self {
            case .cinema: return "film"
            case .reading: return "book"
            case .night: return "moon.fill"
            case .outdoor: return "sun.max"
            case .focus: return "brain"
            }
        }

        public var displayName: String {
            return rawValue.capitalized
        }
    }
    
    private var hardwareUpdateTask: Task<Void, Never>?
    
    public func applyPreset(_ preset: Preset) {
        // UI is updated instantly
        for i in displays.indices {
            displays[i].brightness = preset.brightness
        }
        OSDManager.shared.show(brightness: preset.brightness, icon: preset.icon)
        
        // Start a new task that cancels the previous one
        hardwareUpdateTask?.cancel()
        
        hardwareUpdateTask = Task { @MainActor in
            // Wait for 100ms to allow more clicks to arrive before starting work
            try? await Task.sleep(nanoseconds: 100 * 1_000_000)
            if Task.isCancelled { return }
            
            for display in displays {
                if Task.isCancelled { return }
                
                // Hardware updates are now serialized within this MainActor task.
                await setHardwareBrightnessAsync(for: display, to: preset.brightness)
            }
        }
    }
    
    private func setHardwareBrightnessAsync(for display: Display, to value: Double) async {
        if display.isInternal {
            setInternalBrightness(for: display.id, to: Float(value))
        } else {
            // We run the slow DDC/I2C discovery on a background thread so it never blocks the Main Thread.
            // Explicitly capture immutable values to avoid 'display' or 'self' capture issues.
            let displayID = display.id
            let success = await Task.detached(priority: .background) {
                return DDCManager.setBrightness(for: displayID, to: value)
            }.value
            
            // If hardware failed or it's HDMI on Silicon, use software
            if !success {
                SoftwareDimmingManager.setBrightness(for: displayID, to: value)
            } else {
                SoftwareDimmingManager.setBrightness(for: displayID, to: 1.0)
            }
        }
    }

    public func toggleSync() {
        syncAllDisplays.toggle()
        UserDefaults.standard.set(syncAllDisplays, forKey: syncKey)
    }

    public func toggleAutostart() {
        if #available(macOS 13.0, *) {
            do {
                if autostartEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                checkAutostartStatus()
            } catch {
                print("Failed to toggle autostart: \(error)")
            }
        }
    }

    public func checkAutostartStatus() {
        if #available(macOS 13.0, *) {
            autostartEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private func setInternalBrightness(for id: CGDirectDisplayID, to value: Float) {
        typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                let fun = unsafeBitCast(sym, to: SetBrightness.self)
                _ = fun(id, value)
            }
        }
    }

    private func getInternalBrightness(for id: CGDirectDisplayID) -> Float {
        typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        var brightness: Float = 0.5
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                let fun = unsafeBitCast(sym, to: GetBrightness.self)
                _ = fun(id, &brightness)
            }
        }
        return brightness
    }
}
