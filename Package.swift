// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipPrint",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ClipPrint", path: "Sources/ClipPrint")
    ]
)
