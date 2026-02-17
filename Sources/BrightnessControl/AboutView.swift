import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
    private let appBuild: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()
    
    private var appIcon: NSImage? {
        if let icon = NSImage(named: "MainAppIcon") {
            return icon
        }
        if let icon = NSApp.applicationIconImage {
            return icon
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            } else {
                // Fallback for missing icon or during development
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.gradient)
                    Image(systemName: "sun.max.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                        .foregroundColor(.white)
                }
                .frame(width: 80, height: 80)
            }
            
            VStack(spacing: 4) {
                Text("BrightnessControl")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Version \(appVersion) (\(appBuild))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                if let docURL = Bundle.main.url(forResource: "intro", withExtension: "txt") {
                    Button(action: {
                        // Open in Simple Browser/System Browser to avoid Xcode
                        NSWorkspace.shared.open(docURL)
                    }) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("User Guide (Local Document)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                Button(action: {
                    if let url = URL(string: "https://github.com/jrodan/brightness-control-macos") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "network")
                        Text("Visit GitHub Project")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal, 40)
            
            Text("© 2026 jrodan")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Controller to handle the separate window
class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 350),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView())
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
