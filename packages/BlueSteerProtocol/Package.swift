// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlueSteerProtocol",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "BlueSteerProtocol", targets: ["BlueSteerProtocol"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
    ],
    targets: [
        .target(
            name: "BlueSteerProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]
        ),
        .testTarget(name: "BlueSteerProtocolTests", dependencies: ["BlueSteerProtocol"]),
    ]
)
