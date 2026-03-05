// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mixi2DockerApp",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/apple/swift-configuration", from: "1.1.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "DockerApp",
            dependencies: [
                .product(name: "Mixi2", package: "swift-mixi2"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/DockerApp"
        ),
    ]
)
