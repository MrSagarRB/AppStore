// Turns a designer icon on a white background into transparent, macOS-shaped assets.
//
// Usage: swift prepare-icon.swift <source.png> web <out.png> [size]       tight transparent PNG
//        swift prepare-icon.swift <source.png> iconset <out.iconset>     full macOS iconset
import AppKit

let args = CommandLine.arguments
guard args.count >= 4,
      let source = NSImage(contentsOfFile: args[1]),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("usage: prepare-icon.swift <source.png> web|iconset <out> [size]\n".utf8))
    exit(1)
}

// 1. Find the icon body: the dark/saturated region, ignoring the white backdrop and soft glow.
let w = cg.width, h = cg.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

var rowCount = [Int](repeating: 0, count: h), colCount = [Int](repeating: 0, count: w)
for y in 0..<h { for x in 0..<w where pixels[(y * w + x) * 4] < 70 { rowCount[y] += 1; colCount[x] += 1 } }
let minRun = 40
guard let top = rowCount.firstIndex(where: { $0 > minRun }), let bottom = rowCount.lastIndex(where: { $0 > minRun }),
      let left = colCount.firstIndex(where: { $0 > minRun }), let right = colCount.lastIndex(where: { $0 > minRun }) else {
    FileHandle.standardError.write(Data("could not find icon bounds\n".utf8)); exit(1)
}
let side = min(right - left, bottom - top)
let cx = (left + right) / 2, cy = (top + bottom) / 2
let inset = Int(Double(side) * 0.006)   // trim the anti-aliased white fringe
let crop = CGRect(x: cx - side / 2 + inset, y: cy - side / 2 + inset, width: side - 2 * inset, height: side - 2 * inset)
guard let body = cg.cropping(to: crop) else { exit(1) }

// 2. Render the body clipped to a squircle (superellipse) onto a transparent canvas.
func render(canvas: Int, bodyFraction: Double) -> Data {
    let c = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    let size = Double(canvas) * bodyFraction
    let rect = CGRect(x: (Double(canvas) - size) / 2, y: (Double(canvas) - size) / 2, width: size, height: size)
    let path = CGMutablePath()
    let n = 5.0   // squircle exponent, close to Apple's continuous corner
    for i in 0...360 {
        let t = Double(i) / 360 * 2 * .pi
        let cs = CGFloat(cos(t)), sn = CGFloat(sin(t))
        let e = CGFloat(2 / n)
        let x = rect.midX + rect.width / 2 * (cs < 0 ? -1 : 1) * pow(abs(cs), e)
        let y = rect.midY + rect.height / 2 * (sn < 0 ? -1 : 1) * pow(abs(sn), e)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    c.addPath(path); c.clip()
    c.draw(body, in: rect)
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

switch args[2] {
case "web":
    let size = args.count > 4 ? Int(args[4]) ?? 512 : 512
    try render(canvas: size, bodyFraction: 1).write(to: URL(fileURLWithPath: args[3]))
case "iconset":
    let out = URL(fileURLWithPath: args[3])
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        // macOS icon grid: the body fills 824/1024 of the canvas.
        try render(canvas: base, bodyFraction: 0.8047).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
        try render(canvas: base * 2, bodyFraction: 0.8047).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
default:
    exit(1)
}
