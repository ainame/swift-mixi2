// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mixi2StreamApp",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/apple/swift-configuration", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "StreamApp",
            dependencies: [
                .product(name: "Mixi2", package: "swift-mixi2"),
                .product(name: "Mixi2GRPC", package: "swift-mixi2"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/StreamApp"
        ),
    ]
)
