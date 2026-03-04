// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mixi2Demo",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/apple/swift-configuration", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Demo",
            dependencies: [
                .product(name: "Mixi2", package: "swift-mixi2"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/Demo"
        ),
    ]
)
