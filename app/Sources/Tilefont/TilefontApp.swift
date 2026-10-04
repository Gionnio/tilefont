import AppKit
import SwiftUI

@main
struct TilefontApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some Scene {
        Window("Tilefont", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 620)
                .preferredColorScheme(appTheme.colorScheme)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Informazioni su Tilefont") { AboutWindow.show() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Apri font…") { model.openFont() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Salva immagine…") { model.savePNG() }
                    .keyboardShortcut("s")
                    .disabled(model.map == nil)
                Button("Aggiungi al progetto") { model.exportToProject() }
                    .keyboardShortcut("e")
                    .disabled(model.map == nil || model.projectURL == nil)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Font aperti dal Finder (Apri con, trascinati sull'icona)
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { AppModel.shared.load(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
