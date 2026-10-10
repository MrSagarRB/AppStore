// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipMind",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClipMind", path: "Sources/ClipMind")
    ]
)
