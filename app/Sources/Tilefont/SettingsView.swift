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
    private let initial = LanguagePicker.current

    var body: some View {
        Picker("Lingua", selection: $choice) {
            Text("Sistema").tag("")
            Text(verbatim: "Italiano").tag("it")
            Text(verbatim: "English").tag("en")
        }
        .onChange(of: choice) { _, v in
            if v.isEmpty {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([v], forKey: "AppleLanguages")
            }
        }
        if choice != initial {
            HStack {
                Text("Riavvia Tilefont per applicare la nuova lingua.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button("Riavvia ora") { Self.relaunch() }
            }
        }
    }

    static var current: String {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        return (domain["AppleLanguages"] as? [String])?.first.map { String($0.prefix(2)) } ?? ""
    }

    /// Una nuova istanza parte e questa si chiude
    static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
