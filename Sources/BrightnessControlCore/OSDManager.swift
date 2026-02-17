import SwiftUI
import AppKit

@MainActor
public class OSDManager {
    static let shared = OSDManager()
    private var osdWindow: NSWindow?
    private var hideTimer: Timer?
    private var isHiding = false
    
    public func show(brightness: Double, icon: String = "sun.max.fill") {
        isHiding = false // Reset hiding state if we show again
        
        if osdWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.level = .floating
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let hostingView = NSHostingView(rootView: OSDView(value: brightness, icon: icon))
            window.contentView = hostingView
            osdWindow = window
        } else if let hostingView = osdWindow?.contentView as? NSHostingView<OSDView> {
            hostingView.rootView = OSDView(value: brightness, icon: icon)
            osdWindow?.alphaValue = 1.0 // Reset alpha in case a hide animation was active
        }
        
        centerOnActiveScreen()
        osdWindow?.orderFrontRegardless()
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
    
    private func hide() {
        guard osdWindow != nil, !isHiding else { return }
        isHiding = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            osdWindow?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // Ensure we update UI and state on the MainActor
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Only close if we are still in hiding state (no new show request was made)
                if self.isHiding {
                    self.osdWindow?.close()
                    self.osdWindow = nil
                    self.isHiding = false
                }
            }
        }
    }
    
    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.origin.x + (screenFrame.width - 220) / 2
        let y = screenFrame.origin.y + (screenFrame.height - 220) / 4 // Slightly lower than center for native feel
        osdWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        osdWindow?.alphaValue = 1.0
    }
}

struct OSDView: View {
    let value: Double
    let icon: String
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.primary.opacity(0.85))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.15))
                        
                        Capsule()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(value))
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 30)
            }
            .padding(.top, 10)
        }
        .frame(width: 200, height: 200)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
