// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlightNative",
    platforms: [.macOS("13.1")],
    dependencies: [
        .package(url: "https://github.com/rive-app/rive-ios", from: "6.13.0")
    ],
    targets: [
        .executableTarget(
            name: "AlightNative",
            dependencies: [
                .product(name: "RiveRuntime", package: "rive-ios")
            ],
            path: "Sources/AlightNative",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
