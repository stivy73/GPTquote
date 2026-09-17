import Foundation

enum IconError: LocalizedError {
    case missingArgument
    case missingImage(String)
    case invalidChunkType(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument:
            return "Usage: make-icns <iconset path> <output path>"
        case .missingImage(let name):
            return "Missing icon image: \(name)"
        case .invalidChunkType(let type):
            return "ICNS chunk type must use four ASCII bytes: \(type)"
        }
    }
}

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var number = value.bigEndian
    withUnsafeBytes(of: &number) { data.append(contentsOf: $0) }
}

guard CommandLine.arguments.count == 3 else {
    throw IconError.missingArgument
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let chunks = [
    ("ic04", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("ic05", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var payload = Data()
for (type, fileName) in chunks {
    guard let typeData = type.data(using: .ascii), typeData.count == 4 else {
        throw IconError.invalidChunkType(type)
    }
    let imageURL = iconsetURL.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: imageURL.path) else {
        throw IconError.missingImage(fileName)
    }

    let imageData = try Data(contentsOf: imageURL)
    payload.append(typeData)
    appendBigEndian(UInt32(imageData.count + 8), to: &payload)
    payload.append(imageData)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(payload.count + 8), to: &icns)
icns.append(payload)
try icns.write(to: outputURL, options: .atomic)
