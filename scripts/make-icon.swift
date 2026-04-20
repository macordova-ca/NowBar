import AppKit
import CoreImage

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: make-icon <source.png> <out.png>\n".data(using: .utf8)!)
    exit(1)
}
let srcURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

let size: CGFloat = 1024
let cornerRadius: CGFloat = 230

guard let srcData = try? Data(contentsOf: srcURL),
      let srcImage = NSImage(data: srcData) else {
    FileHandle.standardError.write("cannot load source\n".data(using: .utf8)!)
    exit(1)
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 32
)!
bitmap.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size)

let squircle = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
squircle.addClip()

let top = NSColor(calibratedWhite: 0.22, alpha: 1.0)
let bottom = NSColor(calibratedWhite: 0.06, alpha: 1.0)
let gradient = NSGradient(colors: [top, bottom])!
gradient.draw(in: rect, angle: -90)

let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.12),
    NSColor.white.withAlphaComponent(0.0)
])!
highlight.draw(in: rect, angle: -90)

let pad: CGFloat = 60
let inner = rect.insetBy(dx: pad, dy: pad)

let srcSize = srcImage.size
let scale = min(inner.width / srcSize.width, inner.height / srcSize.height)
let drawSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
let drawRect = NSRect(
    x: inner.midX - drawSize.width / 2,
    y: inner.midY - drawSize.height / 2,
    width: drawSize.width,
    height: drawSize.height
)

var symbolCGImage: CGImage? = nil
if let tiff = srcImage.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let cgSrc = rep.cgImage {
    let ci = CIImage(cgImage: cgSrc)
    let inverted = ci.applyingFilter("CIColorInvert")
    let masked = inverted.applyingFilter("CIMaskToAlpha")
    let ciCtx = CIContext(options: nil)
    symbolCGImage = ciCtx.createCGImage(masked, from: masked.extent)
}

if let sym = symbolCGImage {
    cg.saveGState()
    cg.interpolationQuality = .high
    cg.draw(sym, in: drawRect)
    cg.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("encode failed\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: outURL)
print("wrote \(outURL.path)")
