import AppKit

enum MenuIconError: LocalizedError {
    case usage
    case unreadableImage(String)
    case bitmapCreationFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: make-menu-bar-icon <gpt-mark.png> <output.png>"
        case .unreadableImage(let path):
            return "Could not read image: \(path)"
        case .bitmapCreationFailed:
            return "Could not create the menu bar bitmap."
        case .pngEncodingFailed:
            return "Could not encode the menu bar icon as PNG."
        }
    }
}

guard CommandLine.arguments.count == 3 else {
    throw MenuIconError.usage
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let mark = NSImage(contentsOf: inputURL) else {
    throw MenuIconError.unreadableImage(inputURL.path)
}

let side = 128
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    throw MenuIconError.bitmapCreationFailed
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
mark.draw(in: NSRect(x: 4, y: 4, width: 120, height: 120))
NSGraphicsContext.restoreGraphicsState()

guard let pixels = bitmap.bitmapData else {
    throw MenuIconError.bitmapCreationFailed
}

for pixelIndex in stride(from: 0, to: side * side * 4, by: 4) {
    let red = Double(pixels[pixelIndex])
    let green = Double(pixels[pixelIndex + 1])
    let blue = Double(pixels[pixelIndex + 2])
    let sourceAlpha = Double(pixels[pixelIndex + 3]) / 255
    let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    let logoAlpha = max(0, min(1, (255 - luminance) / 220)) * sourceAlpha

    pixels[pixelIndex] = 0
    pixels[pixelIndex + 1] = 0
    pixels[pixelIndex + 2] = 0
    pixels[pixelIndex + 3] = UInt8((logoAlpha * 255).rounded())
}

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw MenuIconError.pngEncodingFailed
}
try pngData.write(to: outputURL, options: .atomic)
