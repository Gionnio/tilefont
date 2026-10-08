import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("showGrid") private var showGrid = true

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Generale") {
                Picker("Tema", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LanguagePicker()
            }

            Section("Font") {
                Toggle(isOn: $model.variableWidth) {
                    Text("Larghezza variabile")
                    Text("Segna in magenta lo spazio inutilizzato a destra di ogni carattere. Spenta, ogni carattere è largo 8 px.")
                }
                Toggle(isOn: $model.extendedChars) {
                    Text("Caratteri estesi")
                    Text("Disegna anche le caselle 128–255 (lettere accentate, €, simboli) nell'ordine del font di GB Studio. Il file .json salvato accanto al PNG fa trovare a GB Studio €, „, … e gli altri caratteri 128–159.")
                }
                Toggle(isOn: $showGrid) {
                    Text("Griglia nell'anteprima")
                    Text("Mostra le caselle 8×8 sopra l'immagine. Non finisce nel PNG.")
                }
            }

            Section {
                LabeledContent("Progetto") {
                    HStack {
                        Text(model.projectPath.isEmpty ? String(localized: "nessuno") : model.projectPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Scegli…") { model.chooseProject() }
                        if !model.projectPath.isEmpty {
                            Button("Togli") { model.projectPath = "" }
                                .help(String(localized: "Togli il progetto da Tilefont. Il progetto e i suoi file restano dove sono."))
                        }
                    }
                }
            } header: {
                Text("GB Studio")
            } footer: {
                Text("“Aggiungi al progetto” salva il PNG e il suo .json in assets/fonts del progetto: GB Studio li trova da soli.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LanguagePicker: View {
    @State private var choice = LanguagePicker.current
    @State private var askRelaunch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(selection: Binding(get: { choice }, set: { v in
                choice = v
                if v.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([v], forKey: "AppleLanguages")
                }
                askRelaunch = true
            })) {
                Text("Sistema").tag("")
                Text(verbatim: "Italiano").tag("it")
                Text(verbatim: "English").tag("en")
            } label: {
                Text("Lingua")
            }
            Text("Tilefont si riavvia per cambiare lingua.").font(.caption).foregroundStyle(.secondary)
        }
        .alert("Riavviare Tilefont per cambiare lingua?", isPresented: $askRelaunch) {
            Button("Riavvia ora") { Relauncher.relaunch() }
            Button("Più tardi", role: .cancel) {}
        }
    }

    static var current: String {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        return (domain["AppleLanguages"] as? [String])?.first.map { String($0.prefix(2)) } ?? ""
    }
}

/// Chiude l'app e la riapre quando è davvero chiusa, così non ne restano due aperte.
/// La riapertura parte solo se la chiusura va a buon fine (es. confermata con la coda in corso).
enum Relauncher {
    private static var requested: Date?
    private static var observer: NSObjectProtocol?

    static func relaunch() {
        requested = Date()
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                guard let asked = requested, Date().timeIntervalSince(asked) < 120 else { return }
                let pid = ProcessInfo.processInfo.processIdentifier
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
                task.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
                try? task.run()
            }
        }
        for window in NSApp.windows { window.attachedSheet.map { window.endSheet($0) } }
        NSApp.terminate(nil)
    }
}
