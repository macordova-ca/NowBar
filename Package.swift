// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NowBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NowBar")
    ]
)
