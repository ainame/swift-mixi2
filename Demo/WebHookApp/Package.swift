// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mixi2WebHookApp",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "WebHookApp",
            dependencies: [
                .product(name: "Mixi2", package: "swift-mixi2"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/WebHookApp"
        ),
    ]
)
