// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "GPTUsageMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GPTUsageMenu", targets: ["GPTUsageMenu"])
    ],
    targets: [
        .executableTarget(
            name: "GPTUsageMenu",
            path: "Sources/GPTUsageMenu"
        )
    ],
    swiftLanguageVersions: [.v5]
)
