// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickNote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "QuickNote", path: "Sources/QuickNote")
    ]
)
