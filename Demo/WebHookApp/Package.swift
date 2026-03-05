// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Mixi2WebHookApp",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../", traits: ["HummingbirdWebhookAdapter"]),
        .package(url: "https://github.com/apple/swift-configuration", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "WebHookApp",
            dependencies: [
                .product(name: "Mixi2", package: "swift-mixi2"),
                .product(name: "Configuration", package: "swift-configuration"),
            ],
            path: "Sources/WebHookApp"
        ),
    ]
)
