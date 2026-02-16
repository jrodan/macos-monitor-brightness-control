import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var brightnessManager: BrightnessManager?

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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        let _ = { appDelegate.brightnessManager = brightnessManager }()
        
        MenuBarExtra("Brightness", systemImage: "sun.max.fill") {
            VStack(spacing: 12) {
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
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Sync All Displays", isOn: Binding(
                        get: { brightnessManager.syncAllDisplays },
                        set: { _ in brightnessManager.toggleSync() }
                    ))
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
                        NSApplication.shared.orderFrontStandardAboutPanel(nil)
                    }
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding()
            .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
    }
}
