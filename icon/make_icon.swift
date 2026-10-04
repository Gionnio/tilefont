// Icona di Tilefont: squircle con gradiente verde e una casella 8×8 disegnata a mano.
// Uso: swiftc -O make_icon.swift -o /tmp/make_tilefont_icon && /tmp/make_tilefont_icon icon.png

import AppKit


func color(_ hex: String) -> NSColor {
	var value: UInt64 = 0
	Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
	return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let top = color("9BCB3C"), bottom = color("2E6B1F")

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

// Ombra della base
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
NSColor.white.setFill()
squircle.fill()
ctx.restoreGState()

// Gradiente diagonale + riflesso + disco
ctx.saveGState()
squircle.addClip()
NSGradient(colors: [bottom, bottom.blended(withFraction: 0.5, of: top)!, top], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
	.draw(in: rect, angle: 70)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.24), NSColor.white.withAlphaComponent(0)])!
	.draw(in: NSBezierPath(ovalIn: CGRect(x: -20, y: 540, width: 1064, height: 824)), relativeCenterPosition: NSPoint(x: -0.3, y: 0.6))
let disc = NSBezierPath(ovalIn: CGRect(x: 512 - 268, y: 506 - 268, width: 536, height: 536))
NSColor.white.withAlphaComponent(0.15).setFill()
disc.fill()
NSColor.white.withAlphaComponent(0.32).setStroke()
disc.lineWidth = 10
disc.stroke()
ctx.restoreGState()

// Casella 8×8 di GB Studio: una "A" pixel art, una colonna vuota e la parte magenta tolta da GB Studio
let glyph = [
	".XXX.",
	"X...X",
	"X...X",
	"XXXXX",
	"X...X",
	"X...X",
	"X...X",
	".....",
]
let cell: CGFloat = 50
let grid = CGRect(x: 512 - 4 * cell, y: 506 - 4 * cell, width: 8 * cell, height: 8 * cell)
func cellRect(_ col: Int, _ row: Int) -> CGRect {
	CGRect(x: grid.minX + CGFloat(col) * cell, y: grid.maxY - CGFloat(row + 1) * cell, width: cell, height: cell)
}

// Colonne magenta (6 e 7)
ctx.saveGState()
color("FF4FD8").withAlphaComponent(0.9).setFill()
NSBezierPath(roundedRect: CGRect(x: grid.minX + 6 * cell, y: grid.minY, width: 2 * cell, height: 8 * cell), xRadius: 10, yRadius: 10).fill()
ctx.restoreGState()

// Griglia sottile
let lines = NSBezierPath()
for i in 0...8 {
	let x = grid.minX + CGFloat(i) * cell, y = grid.minY + CGFloat(i) * cell
	lines.move(to: CGPoint(x: x, y: grid.minY)); lines.line(to: CGPoint(x: x, y: grid.maxY))
	lines.move(to: CGPoint(x: grid.minX, y: y)); lines.line(to: CGPoint(x: grid.maxX, y: y))
}
NSColor.white.withAlphaComponent(0.3).setStroke()
lines.lineWidth = 3
lines.stroke()

// Pixel bianchi con ombra
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.white.setFill()
for (row, line) in glyph.enumerated() {
	for (col, ch) in line.enumerated() where ch == "X" {
		NSBezierPath(roundedRect: cellRect(col, row).insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6).fill()
	}
}
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Icona creata: \(output)")
