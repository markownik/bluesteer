// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bluesteer-tools",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        .package(path: "../packages/BlueSteerProtocol"),
    ],
    targets: [
        .executableTarget(name: "pty-recorder"),
        .executableTarget(name: "term-bench", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]),
        .executableTarget(name: "ble-bench-peripheral"),
        .executableTarget(name: "channel-probe", dependencies: [.product(name: "BlueSteerProtocol", package: "BlueSteerProtocol")]),
    ]
)
