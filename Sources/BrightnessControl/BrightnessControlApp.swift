import SwiftUI
import AppKit
import BrightnessControlCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var brightnessManager: BrightnessManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicitly set the icon to ensure the Dock gets the right image
        if let icon = NSImage(named: "MainAppIcon") {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        guard let manager = brightnessManager else { return menu }

        for display in manager.displays {
            let displayItem = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
            let subMenu = NSMenu()
            
            let levels = [0.0, 0.25, 0.5, 0.75, 1.0]
            for level in levels {
                let title = "\(Int(level * 100))%"
                let item = NSMenuItem(title: title, action: #selector(setBrightnessFromDock(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = (display.id, level)
                if abs(display.brightness - level) < 0.05 {
                    item.state = .on
                }
                subMenu.addItem(item)
            }
            
            displayItem.submenu = subMenu
            menu.addItem(displayItem)
        }
        
        return menu
    }

    @objc func setBrightnessFromDock(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? (CGDirectDisplayID, Double),
              let manager = brightnessManager else { return }
        Task { @MainActor in
            if let display = manager.displays.first(where: { $0.id == info.0 }) {
                manager.setBrightness(for: display, to: info.1)
            }
        }
    }
}

@main
struct BrightnessControlApp: App {
    @StateObject private var brightnessManager = BrightnessManager()
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var batteryManager = BatteryManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @MainActor
    private var menuBarIcon: NSImage {
        let percentage = batteryManager.percentage
        let showPercentage = batteryManager.showBattery && percentage < 100
        let shouldHideCore = !batteryManager.isOnAC && percentage < 100
        
        let view = ZStack {
            ZStack {
                // Outer Rays
                ForEach(0..<12) { i in
                    Rectangle()
                        .frame(width: 1, height: 4)
                        .offset(y: -8.5)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                
                // Sunny Core
                if !shouldHideCore {
                    Circle()
                        .stroke(lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }
            .foregroundColor(.primary)
            
            if showPercentage {
                Text("\(percentage)")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(.primary)
                    .offset(y: 0.2)
            }
        }
        .frame(width: 22, height: 22)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    var body: some Scene {
        let _ = { appDelegate.brightnessManager = brightnessManager }()
        
        MenuBarExtra {
            VStack(spacing: 0) {
                if brightnessManager.showSceneGallery {
                    // Fancy Scene Gallery
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BrightnessManager.Preset.allCases, id: \.self) { preset in
                                SceneCard(preset: preset, manager: brightnessManager)
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 24) // Added extra trailing padding to prevent clipping
                        .padding(.vertical, 12)
                    }
                    .background(Color.primary.opacity(0.03))
                    
                    Divider()
                }
                
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Display Brightness").font(.headline)
                            Spacer()
                            Button {
                                brightnessManager.refreshDisplays()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                        }
                        
                        ForEach(brightnessManager.displays) { display in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: display.isInternal ? "laptopcomputer" : "display")
                                    Text(display.name).font(.caption).bold()
                                    Spacer()
                                    if display.isSoftwareControl {
                                        Text("Software").font(.system(size: 8)).foregroundColor(.secondary)
                                    }
                                    Text("\(Int(display.brightness * 100))%")
                                        .font(.caption2)
                                        .monospacedDigit()
                                }
                                
                                HStack {
                                    Image(systemName: "sun.min")
                                    Slider(value: Binding(
                                        get: { display.brightness },
                                        set: { brightnessManager.setBrightness(for: display, to: $0) }
                                    ), in: 0...1)
                                    Image(systemName: "sun.max")
                                }

                                if !display.isInternal {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Contrast").font(.system(size: 9))
                                            Slider(value: Binding(
                                                get: { display.contrast },
                                                set: { brightnessManager.setContrast(for: display, to: $0) }
                                            ), in: 0...1).controlSize(.mini)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Volume").font(.system(size: 9))
                                            Slider(value: Binding(
                                                get: { display.volume },
                                                set: { brightnessManager.setVolume(for: display, to: $0) }
                                            ), in: 0...1).controlSize(.mini)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Menu Bar Layout").font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Icon Spacing")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(menuBarManager.spacing))")
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Slider(value: $menuBarManager.spacing, in: 4...16, step: 1)
                                Button("Apply") {
                                    menuBarManager.applyChanges()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button("Reset") {
                                    menuBarManager.resetToDefault()
                                }
                                .controlSize(.small)
                            }
                            
                            if menuBarManager.showRestartWarning {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Relaunch apps to see changes.")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.orange)
                                    
                                    Button(action: {
                                        Task {
                                            await menuBarManager.refreshMenuBarApps()
                                        }
                                    }) {
                                        HStack {
                                            if menuBarManager.isRefreshing {
                                                ProgressView().controlSize(.mini)
                                            }
                                            Text(menuBarManager.isRefreshing ? "Refreshing..." : "Relaunch Apps Now")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(menuBarManager.isRefreshing)
                                }
                            }
                            
                            Toggle("Show Battery in Menu Bar", isOn: $batteryManager.showBattery)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            
                            if batteryManager.showBattery {
                                HStack {
                                    Image(systemName: batteryManager.batteryIconName)
                                        .symbolRenderingMode(.monochrome)
                                        .foregroundColor(batteryManager.batteryColor)
                                    
                                    Text("\(batteryManager.percentage)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(batteryManager.batteryColor)
                                    
                                    Spacer()
                                    
                                    Text(batteryManager.isOnAC ? (batteryManager.isCharging ? "Charging" : "Connected") : "On Battery")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                                .padding(.top, 2)
                            }

                            Button("Battery Settings...") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 10))
                            .padding(.leading, 20)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Sync All Displays", isOn: Binding(
                            get: { brightnessManager.syncAllDisplays },
                            set: { _ in brightnessManager.toggleSync() }
                        ))
                        .toggleStyle(.checkbox)

                        Toggle("Show Scene Gallery", isOn: $brightnessManager.showSceneGallery)
                            .toggleStyle(.checkbox)

                        Toggle("Launch at Login", isOn: Binding(
                            get: { brightnessManager.autostartEnabled },
                            set: { _ in brightnessManager.toggleAutostart() }
                        ))
                        .toggleStyle(.checkbox)
                        
                        Toggle("Show in Dock", isOn: $brightnessManager.showInDock)
                            .toggleStyle(.checkbox)
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("About") {
                            AboutWindowController.shared.show()
                        }
                        Spacer()
                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .keyboardShortcut("q")
                    }
                }
                .padding(16)
            }
            .frame(width: 280)
        } label: {
            if batteryManager.showBattery {
                Image(nsImage: menuBarIcon)
            } else {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct SceneCard: View {
    let preset: BrightnessManager.Preset
    @ObservedObject var manager: BrightnessManager
    
    var body: some View {
        Button {
            manager.applyPreset(preset)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.primary.opacity(0.8))
                }
                
                Text(preset.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
