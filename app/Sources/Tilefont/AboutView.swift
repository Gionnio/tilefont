import AppKit
import SwiftUI

// MARK: - Tema

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: String(localized: "Sistema")
        case .light: String(localized: "Chiaro")
        case .dark: String(localized: "Scuro")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Per le finestre AppKit (Informazioni), dove preferredColorScheme non basta
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Finestra Informazioni

@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        let theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system
        if let window {
            window.appearance = theme.appearance
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = ""
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.appearance = theme.appearance
        w.contentView = NSHostingView(rootView: AboutView())
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 110, height: 110)
                .shadow(radius: 4)

            VStack(spacing: 5) {
                Text("Tilefont")
                    .font(.system(size: 26, weight: .bold))
                Text("Version \(version) (\(build))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(width: 280)
                .padding(.vertical, 4)

            HStack(spacing: 4) {
                Text("Made with")
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text("by Gionnio").fontWeight(.medium)
            }

            Link(destination: URL(string: "https://github.com/Gionnio/tilefont")!) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text("GitHub Repository").fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            Spacer().frame(height: 4)

            VStack(spacing: 3) {
                Text("MIT License")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Copyright © 2026 Gionnio")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(30)
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
    }
}
