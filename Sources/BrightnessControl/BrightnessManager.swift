import Foundation
import CoreGraphics
import AppKit
import ServiceManagement

@MainActor
class BrightnessManager: ObservableObject {
    @Published var displays: [Display] = []
    @Published var autostartEnabled: Bool = false
    @Published var showInDock: Bool = false {
        didSet {
            updateActivationPolicy()
        }
    }
    @Published var syncAllDisplays: Bool = false
    
    private let persistenceKey = "SavedBrightnessLevels"
    private let contrastKey = "SavedContrastLevels"
    private let volumeKey = "SavedVolumeLevels"
    private let dockPersistenceKey = "ShowInDock"
    private let syncKey = "SyncAllDisplays"
    
    init() {
        self.showInDock = UserDefaults.standard.bool(forKey: dockPersistenceKey)
        self.syncAllDisplays = UserDefaults.standard.bool(forKey: syncKey)
        
        refreshDisplays()
        
        checkAutostartStatus()
        setupDisplayCallback()
        updateActivationPolicy()
        setupHotKeys()
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
        for display in displays {
            let newValue = min(max(display.brightness + delta, 0), 1)
            setBrightness(for: display, to: newValue)
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
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        UserDefaults.standard.set(showInDock, forKey: dockPersistenceKey)
    }
    
    func refreshDisplays() {
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
            
            newDisplays.append(display)
            
            // Apply initial brightness
            if isInternal {
                setInternalBrightness(for: displayID, to: Float(display.brightness))
            } else {
                DDCManager.setBrightness(for: displayID, to: display.brightness)
            }
        }
        self.displays = newDisplays
    }

    func setBrightness(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].brightness = value
        }
        
        if display.isInternal {
            setInternalBrightness(for: display.id, to: Float(value))
        } else {
            DDCManager.setBrightness(for: display.id, to: value)
        }
        
        if syncAllDisplays {
            for i in displays.indices {
                if displays[i].id != display.id {
                    displays[i].brightness = value
                    if displays[i].isInternal {
                        setInternalBrightness(for: displays[i].id, to: Float(value))
                    } else {
                        DDCManager.setBrightness(for: displays[i].id, to: value)
                    }
                }
            }
        }
        
        var saved = UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: persistenceKey)
    }

    func setContrast(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].contrast = value
        }
        if !display.isInternal {
            DDCManager.setContrast(for: display.id, to: value)
        }
        var saved = UserDefaults.standard.dictionary(forKey: contrastKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: contrastKey)
    }

    func setVolume(for display: Display, to value: Double) {
        if let index = displays.firstIndex(where: { $0.id == display.id }) {
            displays[index].volume = value
        }
        if !display.isInternal {
            DDCManager.setVolume(for: display.id, to: value)
        }
        var saved = UserDefaults.standard.dictionary(forKey: volumeKey) as? [String: Double] ?? [:]
        saved[display.name] = value
        UserDefaults.standard.set(saved, forKey: volumeKey)
    }

    func toggleSync() {
        syncAllDisplays.toggle()
        UserDefaults.standard.set(syncAllDisplays, forKey: syncKey)
    }

    func toggleAutostart() {
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

    func checkAutostartStatus() {
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
}
