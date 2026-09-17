import AppKit

enum CompositionError: LocalizedError {
    case usage
    case unreadableImage(String)
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: compose-app-icon <background.png> <gpt-mark.png> <output.png>"
        case .unreadableImage(let path):
            return "Could not read image: \(path)"
        case .pngEncodingFailed:
            return "Could not encode the composed app icon as PNG."
        }
    }
}

guard CommandLine.arguments.count == 4 else {
    throw CompositionError.usage
}

let backgroundURL = URL(fileURLWithPath: CommandLine.arguments[1])
let markURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])

guard let background = NSImage(contentsOf: backgroundURL) else {
    throw CompositionError.unreadableImage(backgroundURL.path)
}
guard let mark = NSImage(contentsOf: markURL) else {
    throw CompositionError.unreadableImage(markURL.path)
}

let iconSize = NSSize(width: 1024, height: 1024)
let canvas = NSImage(size: iconSize)
canvas.lockFocus()

background.draw(in: NSRect(origin: .zero, size: iconSize))

let medallion = NSRect(x: 286, y: 286, width: 452, height: 452)
NSGraphicsContext.current?.saveGraphicsState()
NSBezierPath(ovalIn: medallion).addClip()
mark.draw(in: medallion)
NSGraphicsContext.current?.restoreGraphicsState()

canvas.unlockFocus()

guard
    let tiffData = canvas.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    throw CompositionError.pngEncodingFailed
}

try pngData.write(to: outputURL, options: .atomic)
