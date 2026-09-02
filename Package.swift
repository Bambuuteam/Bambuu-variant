// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlightNative",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AlightNative",
            path: "Sources/AlightNative"
        )
    ]
)
