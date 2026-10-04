import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var file: FontFile?
    private(set) var map: FontMap?
    var face = 0 { didSet { if face != oldValue { refit() } } }
    var size = 8 { didSet { if size != oldValue { rerender() } } }
    var variableWidth = UserDefaults.standard.object(forKey: "variableWidth") as? Bool ?? true {
        didSet {
            guard variableWidth != oldValue else { return }
            UserDefaults.standard.set(variableWidth, forKey: "variableWidth")
            rerender()
        }
    }
    var extendedChars = UserDefaults.standard.object(forKey: "extendedChars") as? Bool ?? true {
        didSet {
            guard extendedChars != oldValue else { return }
            UserDefaults.standard.set(extendedChars, forKey: "extendedChars")
            rerender()
        }
    }
    var fontName = ""
    var sampleText = "Hello, GB Studio!"
    var errorMessage: String?
    var notice: String?

    var projectPath = UserDefaults.standard.string(forKey: "projectPath") ?? "" {
        didSet { UserDefaults.standard.set(projectPath, forKey: "projectPath") }
    }

    var projectURL: URL? { projectPath.isEmpty ? nil : URL(fileURLWithPath: projectPath) }

    // MARK: Font

    func openFont() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = FontFile.types
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        do {
            file = try FontFile(url: url)
            errorMessage = nil
            notice = nil
            fontName = Self.sanitize(url.deletingPathExtension().lastPathComponent)
            if face != 0 { face = 0 } else { refit() } // cambiare face rifà già il calcolo
        } catch {
            errorMessage = error.localizedDescription
            notice = nil
        }
    }

    /// Nuovo font o nuovo stile: sceglie la dimensione più grande che entra nelle caselle
    func refit() {
        guard let file else { return }
        let best = FontMap.bestFit(file: file, face: face, variableWidth: variableWidth)
        if best == size { rerender() } else { size = best }
    }

    private func rerender() {
        guard let file else { return }
        map = FontMap.render(font: file.font(face: face, size: size), variableWidth: variableWidth,
                             extended: extendedChars)
    }

    // MARK: Salvataggio

    func savePNG() {
        guard pngData() != nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = exportFileName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    func exportToProject() {
        guard pngData() != nil, let project = projectURL else { return }
        guard GBProject.isProject(project) else {
            errorMessage = String(localized: "La cartella scelta non contiene un progetto GB Studio (.gbsproj).")
            return
        }
        let dir = GBProject.fontsDir(project)
        let url = dir.appendingPathComponent(exportFileName)
        if FileManager.default.fileExists(atPath: url.path) {
            let alert = NSAlert()
            alert.messageText = String(localized: "Sostituire \(exportFileName)?")
            alert.informativeText = String(localized: "Nel progetto esiste già un font con questo nome: verranno sostituiti il PNG e il suo file .json.")
            alert.addButton(withTitle: String(localized: "Sostituisci"))
            alert.addButton(withTitle: String(localized: "Annulla"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        write(to: url)
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "gbsproj") ?? .data, .folder]
        panel.message = String(localized: "Scegli la cartella del progetto GB Studio o il suo file .gbsproj")
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension == "gbsproj" { url.deleteLastPathComponent() }
        guard GBProject.isProject(url) else {
            errorMessage = String(localized: "La cartella scelta non contiene un progetto GB Studio (.gbsproj).")
            return
        }
        errorMessage = nil
        projectPath = url.path
    }

    var exportFileName: String {
        let name = Self.sanitize(fontName)
        return (name.isEmpty ? "font" : name) + ".png"
    }

    private func pngData() -> Data? {
        guard let data = map?.pngData() else {
            errorMessage = String(localized: "Impossibile creare l'immagine.")
            return nil
        }
        return data
    }

    /// Il PNG e, accanto, il .json con il nome del font e la mappatura dei caratteri estesi
    private func write(to url: URL) {
        guard let map, let png = map.pngData(),
              let json = map.metadata(name: fontName.isEmpty ? "font" : fontName) else { return }
        let jsonURL = url.deletingPathExtension().appendingPathExtension("json")
        do {
            try png.write(to: url, options: .atomic)
            try json.write(to: jsonURL, options: .atomic)
            errorMessage = nil
            notice = String(localized: "Salvati \(url.lastPathComponent) e \(jsonURL.lastPathComponent) in \(url.deletingLastPathComponent().path)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func sanitize(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined()
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Progetto GB Studio

enum GBProject {
    static func isProject(_ url: URL) -> Bool {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return items.contains { $0.hasSuffix(".gbsproj") }
    }

    static func fontsDir(_ project: URL) -> URL {
        project.appendingPathComponent("assets/fonts", isDirectory: true)
    }
}
