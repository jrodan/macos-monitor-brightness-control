import Foundation
import AppKit

@MainActor
public class MenuBarManager: ObservableObject {
    @Published public var spacing: Double = 16 {
        didSet {
            UserDefaults.standard.set(spacing, forKey: appPersistenceKey)
        }
    }
    
    @Published public var showRestartWarning: Bool = false
    @Published public var isRefreshing: Bool = false
    
    private let spacingKey = "NSStatusItemSpacing"
    private let paddingKey = "NSStatusItemSelectionPadding"
    private let appPersistenceKey = "SavedMenuBarSpacing"
    
    public init() {
        // Load from our app's persistence, falling back to system default 16
        let savedValue = UserDefaults.standard.double(forKey: appPersistenceKey)
        self.spacing = savedValue == 0 ? 16 : savedValue
    }
    
    public func applyChanges() {
        let val = Int(spacing)
        
        // Write to system defaults
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = [
            "-currentHost", "write", "-globalDomain", spacingKey, "-int", "\(val)"
        ]
        
        let paddingProcess = Process()
        paddingProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        paddingProcess.arguments = [
            "-currentHost", "write", "-globalDomain", paddingKey, "-int", "\(val)"
        ]
        
        do {
            try process.run()
            try paddingProcess.run()
            showRestartWarning = true
        } catch {
            print("Failed to apply menu bar spacing: \(error)")
        }
    }
    
    public func resetToDefault() {
        spacing = 16
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "delete", "-globalDomain", spacingKey]
        
        let paddingProcess = Process()
        paddingProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        paddingProcess.arguments = ["-currentHost", "delete", "-globalDomain", paddingKey]
        
        try? process.run()
        try? paddingProcess.run()
        showRestartWarning = true
    }

    public func refreshMenuBarApps() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // 1. Kill Control Center to refresh system icons
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProcess.arguments = ["ControlCenter"]
        try? killProcess.run()
        killProcess.waitUntilExit()

        // 2. Identify and relaunch user apps with menu bar items
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let menuBarPIDs = getMenuBarAppPIDs()
        
        for pid in menuBarPIDs {
            guard pid != selfPID else { continue }
            
            if let app = NSRunningApplication(processIdentifier: pid),
               let url = app.bundleURL,
               let bid = app.bundleIdentifier {
                
                // Skip critical system apps or ourself
                if bid.hasPrefix("com.apple.WindowManager") || bid == "com.apple.controlcenter" {
                    continue
                }
                
                await relaunchApplication(app: app, at: url)
            }
        }
        
        showRestartWarning = false
    }

    private func getMenuBarAppPIDs() -> Set<pid_t> {
        var pids = Set<pid_t>()
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return pids
        }
        
        for window in windowList {
            // Layer 25/28 are status item layers
            if let layer = window[kCGWindowLayer as String] as? Int,
               (layer == 25 || layer == 28),
               let pid = window[kCGWindowOwnerPID as String] as? pid_t {
                pids.insert(pid)
            }
        }
        return pids
    }

    private func relaunchApplication(app: NSRunningApplication, at url: URL) async {
        app.terminate()
        
        // Wait up to 2 seconds for app to quit
        var attempts = 0
        while !app.isTerminated && attempts < 10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            attempts += 1
        }
        
        if !app.isTerminated {
            app.forceTerminate()
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        
        try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}
