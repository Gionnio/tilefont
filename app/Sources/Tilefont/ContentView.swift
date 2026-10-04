import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 320)
            Divider()
            PreviewPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { model.openFont() } label: {
                    Label("Apri font…", systemImage: "textformat")
                }
                .help(String(localized: "Apri un font TTF, OTF o TTC da convertire (⌘O)"))

                Button { model.savePNG() } label: {
                    Label("Salva immagine…", systemImage: "photo.badge.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                .disabled(model.map == nil)
                .help(model.map == nil
                    ? String(localized: "Apri prima un font")
                    : String(localized: "Salva l'immagine del font (PNG e il suo .json) in una cartella a scelta (⌘S)"))

                Button { model.exportToProject() } label: {
                    Label("Aggiungi al progetto", systemImage: "gamecontroller")
                }
                .labelStyle(.titleAndIcon)
                .disabled(model.map == nil || model.projectURL == nil)
                .help(exportHelp)
            }
        }
    }

    private var exportHelp: String {
        guard model.map != nil else { return String(localized: "Apri prima un font") }
        guard let project = model.projectURL else {
            return String(localized: "Scegli prima un progetto GB Studio nella sezione Esporta")
        }
        return String(localized: "Salva il font in assets/fonts del progetto «\(project.lastPathComponent)», pronto da usare in GB Studio (⌘E)")
    }
}

// MARK: - Barra laterale

private struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Font") {
                FontDropArea()
                if let file = model.file, file.faces.count > 1 {
                    Picker("Stile", selection: $model.face) {
                        ForEach(file.faceNames.indices, id: \.self) { Text(file.faceNames[$0]).tag($0) }
                    }
                }
            }

            Section {
                Stepper(value: $model.size, in: 4...32) {
                    LabeledContent("Dimensione") {
                        Text("\(model.size) pt").monospacedDigit()
                    }
                }
                HStack {
                    Spacer()
                    Button("Adatta alle caselle") { model.refit() }
                }
                Toggle(isOn: $model.variableWidth) {
                    Text("Larghezza variabile")
                    Text("Colora di magenta la parte di casella a destra di ogni carattere, che GB Studio toglie.")
                }
                Toggle(isOn: $model.extendedChars) {
                    Text("Caratteri estesi")
                    Text("Accentate e simboli (128–255) come nel font di GB Studio. Spenta, solo ASCII.")
                }
            } header: {
                Text("Griglia 8×8")
            } footer: {
                Text("I font pixel danno il risultato più pulito alla loro dimensione nativa (spesso 8 o 16 pt).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(model.file == nil)

            Section("Esporta") {
                TextField("Nome del font", text: $model.fontName, prompt: Text("font"))
                LabeledContent("Progetto") {
                    HStack {
                        Text(model.projectURL?.lastPathComponent ?? String(localized: "nessuno"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .help(model.projectPath)
                        Button("Scegli…") { model.chooseProject() }
                    }
                }
                if let project = model.projectURL {
                    Text(verbatim: GBProject.fontsDir(project).appendingPathComponent(model.exportFileName).path
                        .replacingOccurrences(of: NSHomeDirectory(), with: "~") + " + .json")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct FontDropArea: View {
    @Environment(AppModel.self) private var model
    @State private var targeted = false

    var body: some View {
        Button { model.openFont() } label: {
            VStack(spacing: 8) {
                if let file = model.file {
                    Image(systemName: "textformat")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentColor)
                    Text(file.faceNames[min(model.face, file.faceNames.count - 1)])
                        .font(.headline)
                        .lineLimit(1)
                    Text(file.url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("Trascina qui un font")
                        .font(.headline)
                    Text("TTF, OTF o TTC · oppure fai clic per sceglierlo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .background(targeted ? Color.accentColor.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                  style: StrokeStyle(lineWidth: targeted ? 3 : 1.5, dash: targeted ? [] : [6, 4]))
            }
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.load(url)
            return true
        } isTargeted: { targeted = $0 }
    }
}

// MARK: - Anteprima

private struct PreviewPane: View {
    @Environment(AppModel.self) private var model
    @AppStorage("showGrid") private var showGrid = true

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let map = model.map {
                    HStack {
                        Text("Immagine font")
                            .font(.headline)
                        Text(verbatim: "128 × 112")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Griglia", isOn: $showGrid)
                            .toggleStyle(.checkbox)
                    }
                    PixelView(pixels: map.pixels, width: FontMap.width, height: FontMap.height,
                              scale: 4, grid: showGrid ? FontMap.tile : nil)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prova del testo")
                            .font(.headline)
                        TextField("Testo di prova", text: $model.sampleText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 512)
                        let sample = map.sample(model.sampleText)
                        if sample.width > 0 {
                            ScrollView(.horizontal) {
                                PixelView(pixels: sample.pixels, width: sample.width, height: FontMap.tile,
                                          scale: 3, grid: nil)
                            }
                            .frame(maxWidth: 512, alignment: .leading)
                        }
                        Text("Composto come in GB Studio, con la larghezza di ogni carattere.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    StatusList(map: map)
                } else {
                    ContentUnavailableView {
                        Label("Nessun font", systemImage: "square.grid.3x3")
                    } description: {
                        Text("Apri un font per creare l'immagine 128×112 da usare in GB Studio.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                }

                if let error = model.errorMessage {
                    StatusRow(icon: "xmark.octagon.fill", color: .red, text: error)
                }
                if let notice = model.notice {
                    StatusRow(icon: "checkmark.circle.fill", color: .green, text: notice)
                }
            }
            .padding(24)
        }
    }
}

private struct StatusList: View {
    let map: FontMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if map.isClean {
                StatusRow(icon: "checkmark.seal.fill", color: .green,
                          text: String(localized: "\(map.drawnCount) caratteri disegnati, tutti dentro le caselle."))
            }
            if !map.tooTall.isEmpty {
                StatusRow(icon: "exclamationmark.triangle.fill", color: .orange,
                          text: String(localized: "Troppo alti, tagliati in basso: \(Self.list(map.tooTall))"))
            }
            if !map.tooWide.isEmpty {
                StatusRow(icon: "exclamationmark.triangle.fill", color: .orange,
                          text: String(localized: "Troppo larghi, tagliati a destra: \(Self.list(map.tooWide))"))
            }
            if !map.lowered.isEmpty {
                StatusRow(icon: "info.circle.fill", color: .blue,
                          text: String(localized: "Abbassati per non tagliare l'accento: \(Self.list(map.lowered))"))
            }
            if !map.missing.isEmpty {
                StatusRow(icon: "info.circle.fill", color: .blue,
                          text: String(localized: "Non presenti nel font, caselle vuote: \(Self.list(map.missing))"))
            }
        }
    }

    static func list(_ chars: [Character]) -> String {
        chars.map(String.init).joined(separator: " ")
    }
}

struct StatusRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        Label {
            Text(text).textSelection(.enabled)
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Pixel ingranditi senza sfumature, con griglia facoltativa ogni `grid` pixel
struct PixelView: View {
    let pixels: [FontMap.Pixel]
    let width: Int
    let height: Int
    let scale: Int
    let grid: Int?

    var body: some View {
        Canvas { ctx, size in
            guard let image = FontMap.image(pixels: pixels, width: width, height: height) else { return }
            ctx.withCGContext { cg in
                cg.interpolationQuality = .none
                cg.saveGState()
                cg.translateBy(x: 0, y: size.height)
                cg.scaleBy(x: 1, y: -1)
                cg.draw(image, in: CGRect(origin: .zero, size: size))
                cg.restoreGState()
            }
            guard let grid else { return }
            var path = Path()
            let step = CGFloat(grid * scale)
            for x in stride(from: step, to: size.width, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: step, to: size.height, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.cyan.opacity(0.5)), lineWidth: 1)
        }
        .frame(width: CGFloat(width * scale), height: CGFloat(height * scale))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.4)))
    }
}
