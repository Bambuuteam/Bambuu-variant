// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlightNative",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "AlightNative",
            path: "Sources/AlightNative"
        )
    ]
)
