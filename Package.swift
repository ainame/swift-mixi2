// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mixi2",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "Mixi2", targets: ["Mixi2"]),
        .library(name: "Mixi2GRPC", targets: ["Mixi2GRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        .package(url: "https://github.com/swiftlang/swift-testing", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "Mixi2GRPC",
            dependencies: [
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            ],
            path: "Sources/Mixi2GRPC"
        ),
        .target(
            name: "Mixi2",
            dependencies: [
                "Mixi2GRPC",
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/Mixi2"
        ),
        .testTarget(
            name: "Mixi2Tests",
            dependencies: [
                "Mixi2",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/Mixi2Tests"
        ),
    ]
)
