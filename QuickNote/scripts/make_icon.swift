// Draws the QuickNote icon (stacked sticky notes on a warm squircle).
// Usage: swift make_icon.swift web <out.png> [size]     transparent PNG for the website
//        swift make_icon.swift iconset <out.iconset>    full macOS iconset
import AppKit

func squircle(_ rect: CGRect, n: Double = 5) -> CGPath {
    let path = CGMutablePath()
    for i in 0...360 {
        let t = Double(i) / 360 * 2 * .pi
        let c = CGFloat(cos(t)), s = CGFloat(sin(t))
        let e = CGFloat(2 / n)
        let x = rect.midX + rect.width / 2 * (c < 0 ? -1 : 1) * pow(abs(c), e)
        let y = rect.midY + rect.height / 2 * (s < 0 ? -1 : 1) * pow(abs(s), e)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func note(_ ctx: CGContext, center: CGPoint, size: CGSize, degrees: CGFloat, fill: NSColor, lines: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    ctx.setFillColor(fill.cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    if lines {
        ctx.setFillColor(NSColor(red: 0.30, green: 0.24, blue: 0.12, alpha: 0.55).cgColor)
        for (i, w) in [0.62, 0.62, 0.38].enumerated() {
            let bar = CGRect(x: rect.minX + size.width * 0.16, y: rect.maxY - size.height * (0.30 + 0.17 * CGFloat(i)),
                             width: size.width * w, height: 30)
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 15, cornerHeight: 15, transform: nil))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()
}

func render(px: Int, bodyFraction: Double) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let size = Double(px) * bodyFraction
    ctx.translateBy(x: (Double(px) - size) / 2, y: (Double(px) - size) / 2)
    ctx.scaleBy(x: size / 1000, y: size / 1000)

    ctx.saveGState()
    ctx.addPath(squircle(CGRect(x: 0, y: 0, width: 1000, height: 1000)))
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 1.00, green: 0.88, blue: 0.36, alpha: 1).cgColor,
        NSColor(red: 1.00, green: 0.62, blue: 0.22, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 300, y: 1000), end: CGPoint(x: 700, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    note(ctx, center: CGPoint(x: 560, y: 540), size: CGSize(width: 470, height: 470), degrees: -11,
         fill: NSColor(red: 0.98, green: 0.62, blue: 0.78, alpha: 1), lines: false)
    note(ctx, center: CGPoint(x: 470, y: 500), size: CGSize(width: 500, height: 500), degrees: 5,
         fill: NSColor(red: 1.0, green: 0.99, blue: 0.93, alpha: 1), lines: true)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count >= 3 else { exit(1) }
switch args[1] {
case "web":
    try render(px: args.count > 3 ? Int(args[3]) ?? 512 : 512, bodyFraction: 1).write(to: URL(fileURLWithPath: args[2]))
case "iconset":
    let out = URL(fileURLWithPath: args[2])
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        try render(px: base, bodyFraction: 0.8047).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
        try render(px: base * 2, bodyFraction: 0.8047).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
default: exit(1)
}
