import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - File del font

struct FontFile {
    enum LoadError: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name): String(localized: "\(name) non è un font leggibile.")
            }
        }
    }

    static let types: [UTType] = [.font]

    let url: URL
    let faces: [CTFontDescriptor]
    let faceNames: [String]

    init(url: URL) throws {
        guard let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              !list.isEmpty else {
            throw LoadError.unreadable(url.lastPathComponent)
        }
        self.url = url
        faces = list
        faceNames = list.map {
            (CTFontDescriptorCopyAttribute($0, kCTFontDisplayNameAttribute) as? String)
                ?? (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String)
                ?? url.deletingPathExtension().lastPathComponent
        }
    }

    func font(face: Int, size: Int) -> CTFont {
        CTFontCreateWithFontDescriptor(faces[min(max(face, 0), faces.count - 1)], CGFloat(size), nil)
    }
}

// MARK: - Mappa GB Studio

/// Immagine font di GB Studio: 128×112 px, 16×14 caselle di 8×8, la casella 0 è il carattere 32 (spazio).
/// Colori come i font inclusi in GB Studio: verde chiaro = sfondo, verde scurissimo = glifo, magenta = parte
/// della casella da togliere. Il bianco puro non va usato: GB Studio lo tratta come il magenta.
struct FontMap: Equatable {
    enum Pixel: UInt8 { case paper = 0, ink = 1, cut = 2 }

    static let columns = 16
    static let rows = 14
    static let tile = 8
    static let width = columns * tile // 128
    static let height = rows * tile // 112
    static let firstCode = 32
    static let asciiCodes = 32...126
    static let allCodes = 32...255

    /// Caselle 128–159: i caratteri di Windows-1252, come nel font di GB Studio. Senza voce = casella vuota.
    static let cp1252: [Int: Character] = [
        0x80: "€", 0x82: "‚", 0x83: "ƒ", 0x84: "„", 0x85: "…", 0x86: "†", 0x87: "‡", 0x88: "ˆ",
        0x89: "‰", 0x8A: "Š", 0x8B: "‹", 0x8C: "Œ", 0x8E: "Ž", 0x91: "‘", 0x92: "’", 0x93: "“",
        0x94: "”", 0x95: "•", 0x96: "–", 0x97: "—", 0x98: "˜", 0x99: "™", 0x9A: "š", 0x9B: "›",
        0x9C: "œ", 0x9E: "ž", 0x9F: "Ÿ",
    ]

    /// Carattere disegnato nella casella `code` (nil = casella vuota)
    static func character(for code: Int) -> Character? {
        switch code {
        case 32...126, 160...255: Character(UnicodeScalar(UInt8(code)))
        case 128...159: cp1252[code]
        default: nil
        }
    }

    /// Casella di un carattere digitato in GB Studio (con la mappatura del file .json per 128–159)
    static func code(for scalar: Unicode.Scalar) -> Int? {
        let v = Int(scalar.value)
        if (32...126).contains(v) || (160...255).contains(v) { return v }
        return cp1252.first { $0.value.unicodeScalars.first == scalar }?.key
    }

    var pixels = [Pixel](repeating: .paper, count: width * height)
    /// Larghezza in pixel di ogni carattere disegnato (8 se a larghezza fissa)
    var widths: [Int: Int] = [:]
    var missing: [Character] = []
    var tooTall: [Character] = []
    var tooWide: [Character] = []
    /// Caratteri (di solito maiuscole accentate) abbassati sotto la linea di base per non tagliare l'accento
    var lowered: [Character] = []
    var drawnCount = 0

    var isClean: Bool { tooTall.isEmpty && tooWide.isEmpty }

    subscript(x: Int, y: Int) -> Pixel {
        get { pixels[y * Self.width + x] }
        set { pixels[y * Self.width + x] = newValue }
    }

    static func origin(of code: Int) -> (x: Int, y: Int) {
        let i = code - firstCode
        return (i % columns * tile, i / columns * tile)
    }

    // MARK: Rendering

    /// Punto di inchiostro relativo alla penna: dx verso destra, up verso l'alto (0 = riga sopra la linea di base)
    private struct Ink { let dx: Int; let up: Int }

    private struct Glyph {
        let code: Int
        let char: Character
        let ink: [Ink]
        let advance: Int
        let missing: Bool
    }

    static func render(font: CTFont, variableWidth: Bool, extended: Bool) -> FontMap {
        let codes = extended ? allCodes : asciiCodes
        let glyphs = codes.compactMap { code in
            character(for: code).map { rasterize(code: code, char: $0, font: font) }
        }
        var map = FontMap()

        // Linea di base unica, decisa dai caratteri ASCII: il loro pixel più alto va sulla riga 0.
        // Le lettere accentate più alte vengono abbassate quel tanto che basta per tenere l'accento.
        let top = glyphs.filter { asciiCodes.contains($0.code) }.flatMap { $0.ink.map(\.up) }.max() ?? 0

        for g in glyphs {
            if g.missing {
                map.missing.append(g.char)
                continue
            }
            map.drawnCount += 1
            let (ox, oy) = origin(of: g.code)
            let minDx = g.ink.map(\.dx).min() ?? 0
            let maxDx = g.ink.map(\.dx).max() ?? 0
            let maxUp = g.ink.map(\.up).max() ?? 0
            // Larghezza variabile: glifo appoggiato a sinistra. Fissa: posizione del font, senza uscire a sinistra.
            let shift = variableWidth ? -minDx : max(0, -minDx)
            let drop = max(0, maxUp - top)
            if drop > 0 { map.lowered.append(g.char) }
            var tall = false, wide = false

            for p in g.ink {
                let col = p.dx + shift
                let row = top + drop - p.up
                guard col < tile else { wide = true; continue }
                guard row < tile else { tall = true; continue }
                map[ox + col, oy + row] = .ink
            }
            if tall { map.tooTall.append(g.char) }
            if wide { map.tooWide.append(g.char) }

            guard variableWidth else {
                map.widths[g.code] = tile
                continue
            }
            // Una colonna vuota dopo il glifo fa da spaziatura; gli spazi usano l'avanzamento del font
            let width = g.ink.isEmpty
                ? min(max(g.advance, 1), tile)
                : min(maxDx - minDx + 2, tile)
            map.widths[g.code] = width
            for col in width..<tile {
                for row in 0..<tile { map[ox + col, oy + row] = .cut }
            }
        }
        return map
    }

    /// Copertura minima perché un pixel diventi nero. Disegnare senza antialiasing perde i tratti più
    /// sottili di un pixel (a 7–8 px le lettere si spezzano); il 30% li tiene senza ingrassare il testo.
    /// I font pixel alla loro dimensione nativa coprono i pixel per intero e restano identici.
    private static let inkCoverage = 0.3

    /// Disegna il glifo in scala di grigi su una tela grande e ne raccoglie i pixel abbastanza coperti
    private static func rasterize(code: Int, char: Character, font: CTFont) -> Glyph {
        var unichar = UniChar(char.unicodeScalars.first?.value ?? 32)
        var glyph = CGGlyph(0)
        let found = CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
        var advanceSize = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advanceSize, 1)
        let advance = Int(advanceSize.width.rounded())
        guard found, glyph != 0 else {
            return Glyph(code: code, char: char, ink: [], advance: advance, missing: code != 32)
        }

        let size = Int(CTFontGetSize(font))
        let canvas = size * 4 + 16
        let penX = canvas / 4, penY = canvas / 3
        guard let ctx = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8,
                                  bytesPerRow: canvas, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return Glyph(code: code, char: char, ink: [], advance: advance, missing: true)
        }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldSubpixelPositionFonts(false)
        ctx.setShouldSubpixelQuantizeFonts(false)
        ctx.setFillColor(gray: 0, alpha: 1)
        var position = CGPoint(x: penX, y: penY)
        CTFontDrawGlyphs(font, &glyph, &position, 1, ctx)

        let threshold = UInt8(255 * (1 - inkCoverage))
        var ink: [Ink] = []
        if let data = ctx.data?.assumingMemoryBound(to: UInt8.self) {
            for row in 0..<canvas {
                for x in 0..<canvas where data[row * canvas + x] < threshold {
                    // La memoria parte dall'alto, le coordinate di Core Graphics dal basso
                    ink.append(Ink(dx: x - penX, up: canvas - 1 - row - penY))
                }
            }
        }
        return Glyph(code: code, char: char, ink: ink, advance: advance, missing: false)
    }

    /// Dimensione più grande (in pt) in cui tutti i caratteri ASCII stanno nelle caselle 8×8
    static func bestFit(file: FontFile, face: Int, variableWidth: Bool) -> Int {
        for size in stride(from: 32, through: 4, by: -1) {
            if render(font: file.font(face: face, size: size), variableWidth: variableWidth, extended: false).isClean {
                return size
            }
        }
        return 4
    }

    // MARK: Anteprima di un testo

    /// Testo composto come in GB Studio: ogni carattere occupa la sua larghezza. Righe di 8 px.
    func sample(_ text: String) -> (pixels: [Pixel], width: Int) {
        let codes = text.unicodeScalars.compactMap(Self.code(for:)).filter { widths[$0] != nil }
        let total = codes.reduce(0) { $0 + (widths[$1] ?? 0) }
        guard total > 0 else { return ([], 0) }
        var out = [Pixel](repeating: .paper, count: total * Self.tile)
        var cursor = 0
        for code in codes {
            let w = widths[code] ?? 0
            let (ox, oy) = Self.origin(of: code)
            for row in 0..<Self.tile {
                for col in 0..<w where self[ox + col, oy + row] == .ink {
                    out[row * total + cursor + col] = .ink
                }
            }
            cursor += w
        }
        return (out, total)
    }

    // MARK: Esportazione

    static func image(pixels: [Pixel], width: Int, height: Int) -> CGImage? {
        var bytes = [UInt8]()
        bytes.reserveCapacity(pixels.count * 4)
        for p in pixels {
            switch p {
            case .paper: bytes += [224, 248, 207, 255] // #E0F8CF
            case .ink: bytes += [7, 24, 33, 255] // #071821
            case .cut: bytes += [255, 0, 255, 255]
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    var cgImage: CGImage? { Self.image(pixels: pixels, width: Self.width, height: Self.height) }

    func pngData() -> Data? {
        guard let image = cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    /// File .json che GB Studio legge accanto al PNG: nome mostrato nell'editor e mappatura dei caratteri
    /// 128–159, che altrimenti GB Studio cercherebbe nella casella sbagliata (usa il codice Unicode).
    func metadata(name: String) -> Data? {
        var mapping: [String: Int] = [:]
        for (code, char) in Self.cp1252 where widths[code] != nil {
            mapping[String(char)] = code
        }
        let json: [String: Any] = ["name": name, "mapping": mapping]
        return try? JSONSerialization.data(withJSONObject: json,
                                           options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
